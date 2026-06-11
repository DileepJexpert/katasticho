package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.inventory.service.FifoCostingService;
import com.katasticho.erp.sales.entity.DeliveryChallan;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
@Slf4j
public class SalesInvoicePostingRule implements PostingRuleStrategy {

    private final DefaultAccountService defaultAccountService;
    private final TaxLineItemRepository taxLineItemRepository;
    private final ItemRepository itemRepository;
    private final FifoCostingService fifoCostingService;
    private final DeliveryChallanRepository deliveryChallanRepository;
    private final StockMovementRepository stockMovementRepository;

    @Override
    public boolean supports(String sourceType) {
        return PostingContext.SALES_INVOICE.equals(sourceType);
    }

    @Override
    public JournalPostRequest generate(PostingContext context) {
        Invoice invoice = context.requireSalesInvoice();
        UUID orgId = invoice.getOrgId();
        List<JournalLineRequest> lines = new ArrayList<>();

        lines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                invoice.getTotalAmount(), BigDecimal.ZERO,
                "AR: " + invoice.getInvoiceNumber(),
                null, null));

        for (InvoiceLine line : invoice.getLines()) {
            if (line.getTaxableAmount() == null
                    || line.getTaxableAmount().compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }
            lines.add(new JournalLineRequest(
                    line.getAccountCode(),
                    BigDecimal.ZERO, line.getTaxableAmount(),
                    "Revenue: " + line.getDescription(),
                    null, null));
        }

        appendTaxPayableLines(lines, invoice);

        // TCS 206C(1H): collected from the buyer (already in totalAmount → AR
        // debit), owed to the government until deposited.
        if (invoice.getTcsAmount() != null && invoice.getTcsAmount().signum() > 0) {
            lines.add(new JournalLineRequest(
                    defaultAccountService.getCode(orgId, DefaultAccountPurpose.TCS_PAYABLE),
                    BigDecimal.ZERO, invoice.getTcsAmount(),
                    "TCS 206C(1H): " + invoice.getInvoiceNumber(),
                    null, null));
        }

        appendCogs(lines, invoice);

        return new JournalPostRequest(
                invoice.getInvoiceDate(),
                "Invoice " + invoice.getInvoiceNumber(),
                "SALES",
                invoice.getId(),
                lines,
                true);
    }

    private void appendTaxPayableLines(List<JournalLineRequest> lines, Invoice invoice) {
        List<TaxLineItem> taxLines = taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoice.getId());
        for (TaxLineItem tli : taxLines) {
            requireTaxGlAccount(tli);
            lines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    BigDecimal.ZERO, tli.getTaxAmount(),
                    tli.getComponentCode() + " Payable",
                    tli.getComponentCode(), null));
        }
    }

    private void appendCogs(List<JournalLineRequest> lines, Invoice invoice) {
        List<InvoiceLine> invoiceLines = invoice.getLines();
        Set<UUID> itemIds = invoiceLines.stream()
                .map(InvoiceLine::getItemId).filter(Objects::nonNull)
                .collect(Collectors.toSet());
        if (itemIds.isEmpty()) {
            return;
        }

        // Per-item blended FIFO unit cost of the dispatched goods. Each
        // invoice line is costed at (its OWN quantity × that unit cost), so a
        // partial invoice takes only its share and a second invoice on the
        // same SO can never re-count cost the first already booked.
        Map<UUID, BigDecimal> fifoUnitCost = fifoUnitCosts(invoice);

        var items = itemRepository.findAllById(itemIds).stream()
                .collect(Collectors.toMap(Item::getId, item -> item));

        BigDecimal totalCost = BigDecimal.ZERO;
        for (InvoiceLine line : invoiceLines) {
            if (line.getItemId() == null) continue;
            BigDecimal unit = fifoUnitCost.get(line.getItemId());
            if (unit != null) {
                totalCost = totalCost.add(unit.multiply(line.getQuantity()))
                        .setScale(2, RoundingMode.HALF_UP);
                continue;
            }
            // No dispatched movement for this item (weighted-average org, or
            // FIFO with no attributable movement) → purchase-price fallback,
            // the basis used before FIFO and for non-distributor flows.
            Item item = items.get(line.getItemId());
            if (item == null || !item.isTrackInventory()) continue;
            if (item.getPurchasePrice() == null || item.getPurchasePrice().compareTo(BigDecimal.ZERO) <= 0) continue;
            totalCost = totalCost.add(item.getPurchasePrice()
                    .multiply(line.getQuantity())
                    .setScale(2, RoundingMode.HALF_UP));
        }
        if (totalCost.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }

        String cogsCode;
        String inventoryCode;
        try {
            cogsCode = defaultAccountService.getCode(invoice.getOrgId(), DefaultAccountPurpose.COGS);
            inventoryCode = defaultAccountService.getCode(invoice.getOrgId(), DefaultAccountPurpose.INVENTORY_ASSET);
        } catch (BusinessException e) {
            log.warn("COGS/inventory accounts not configured for org {}, skipping COGS entry for invoice {}",
                    invoice.getOrgId(), invoice.getId());
            return;
        }
        lines.add(new JournalLineRequest(
                cogsCode,
                totalCost, BigDecimal.ZERO,
                "COGS: " + invoice.getInvoiceNumber(),
                null, null));
        lines.add(new JournalLineRequest(
                inventoryCode,
                BigDecimal.ZERO, totalCost,
                "Inventory: " + invoice.getInvoiceNumber(),
                null, null));
    }

    /**
     * Per-item blended FIFO unit cost of the goods this invoice bills for,
     * derived from the actual recorded cost of their SALE stock movements.
     * SO-path invoices attribute through the SO's delivery challans (goods
     * leave at DC dispatch); direct invoices attribute through their own SALE
     * movements (stock is deducted before the journal posts). Returns an empty
     * map for weighted-average orgs or when nothing is attributable, letting
     * the caller fall back to purchase price. Composite items move stock as
     * their BOM children, so the parent line falls back — same as the
     * weighted-average basis.
     */
    private Map<UUID, BigDecimal> fifoUnitCosts(Invoice invoice) {
        UUID orgId = invoice.getOrgId();
        if (!fifoCostingService.isFifo(orgId)) {
            return Map.of();
        }
        List<UUID> refIds;
        ReferenceType refType;
        if (invoice.getSalesOrderId() != null) {
            List<DeliveryChallan> challans = deliveryChallanRepository
                    .findBySalesOrderIdAndOrgIdAndIsDeletedFalse(invoice.getSalesOrderId(), orgId);
            if (challans.isEmpty()) {
                return Map.of();
            }
            refType = ReferenceType.DELIVERY_CHALLAN;
            refIds = challans.stream().map(DeliveryChallan::getId).collect(Collectors.toList());
        } else {
            refType = ReferenceType.INVOICE;
            refIds = List.of(invoice.getId());
        }
        Map<UUID, BigDecimal> unitCosts = new HashMap<>();
        for (StockMovementRepository.ItemCostRow row : stockMovementRepository
                .sumCostAndQtyByReferences(orgId, refType, refIds, MovementType.SALE)) {
            if (row.getTotalQty() == null || row.getTotalQty().signum() <= 0) continue;
            unitCosts.put(row.getItemId(),
                    row.getTotalCost().divide(row.getTotalQty(), 4, RoundingMode.HALF_UP));
        }
        return unitCosts;
    }

    private void requireTaxGlAccount(TaxLineItem tli) {
        if (tli.getAccountCode() == null || tli.getAccountCode().isBlank()) {
            throw new BusinessException(
                    "Missing tax account mapping for " + tli.getComponentCode(),
                    "TAX_ACCOUNT_MAPPING_MISSING",
                    HttpStatus.CONFLICT
            );
        }
    }
}
