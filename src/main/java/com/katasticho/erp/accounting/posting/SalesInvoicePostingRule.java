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
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
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

        var items = itemRepository.findAllById(itemIds).stream()
                .collect(Collectors.toMap(Item::getId, item -> item));
        BigDecimal totalCost = BigDecimal.ZERO;
        for (InvoiceLine line : invoiceLines) {
            if (line.getItemId() == null) continue;
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
