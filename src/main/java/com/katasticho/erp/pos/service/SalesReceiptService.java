package com.katasticho.erp.pos.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.BatchService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.pos.dto.CreateSalesReceiptRequest;
import com.katasticho.erp.pos.dto.SalesReceiptResponse;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import com.katasticho.erp.tax.TaxEngine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * POS Sales Receipt — one-shot transaction. No DRAFT state.
 * <ol>
 *   <li>Generate receipt number (SR-YYYY-NNNNNN)</li>
 *   <li>Calculate line totals + tax via TaxEngine</li>
 *   <li>Post journal — DR paid-through, CR Revenue, CR Tax Payable</li>
 *   <li>Deduct stock for tracked items</li>
 *   <li>Return completed receipt</li>
 * </ol>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SalesReceiptService {

    private static final String RECEIPT_PREFIX = "SR";

    private final SalesReceiptRepository receiptRepository;
    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final ContactRepository contactRepository;
    private final JournalService journalService;
    private final InventoryService inventoryService;
    private final BatchService batchService;
    private final TaxEngine taxEngine;
    private final AuditService auditService;
    private final DefaultAccountService defaultAccountService;

    @Transactional
    public SalesReceiptResponse create(CreateSalesReceiptRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        // 1. Generate receipt number
        int year = request.receiptDate().getYear();
        String receiptNumber = generateNumber(orgId, RECEIPT_PREFIX, year);

        // 2. Build receipt entity
        SalesReceipt receipt = SalesReceipt.builder()
                .branchId(request.branchId())
                .receiptNumber(receiptNumber)
                .contactId(request.contactId())
                .receiptDate(request.receiptDate())
                .paymentMode(request.paymentMode())
                .paidThroughId(request.paidThroughId())
                .amountReceived(request.amountReceived())
                .upiReference(request.upiReference())
                .notes(request.notes())
                .build();
        receipt.setOrgId(orgId);
        receipt.setCreatedBy(userId);

        // 3. Process line items — compute tax, build lines
        BigDecimal subtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();

        // Pre-load all items referenced by lines
        List<UUID> itemIds = request.lines().stream()
                .map(CreateSalesReceiptRequest.LineRequest::itemId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        Map<UUID, Item> itemMap = itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, itemIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, Function.identity()));

        for (int i = 0; i < request.lines().size(); i++) {
            var lineReq = request.lines().get(i);

            BigDecimal lineAmount = lineReq.rate().multiply(lineReq.quantity())
                    .setScale(2, RoundingMode.HALF_UP);

            // Tax calculation
            UUID taxGroupId = lineReq.taxGroupId();
            if (taxGroupId == null && lineReq.itemId() != null) {
                Item item = itemMap.get(lineReq.itemId());
                if (item != null) {
                    taxGroupId = item.getDefaultTaxGroupId();
                }
            }

            TaxEngine.TaxCalculationResult taxResult = taxEngine.calculate(
                    orgId, taxGroupId, lineAmount, TaxEngine.TransactionType.SALE);
            BigDecimal lineTax = taxResult.totalTaxAmount();

            SalesReceiptLine line = SalesReceiptLine.builder()
                    .lineNumber(i + 1)
                    .itemId(lineReq.itemId())
                    .description(lineReq.description() != null ? lineReq.description()
                            : (lineReq.itemId() != null && itemMap.containsKey(lineReq.itemId())
                            ? itemMap.get(lineReq.itemId()).getName() : null))
                    .quantity(lineReq.quantity())
                    .unit(lineReq.unit())
                    .rate(lineReq.rate())
                    .taxGroupId(taxGroupId)
                    .hsnCode(lineReq.hsnCode())
                    .amount(lineAmount)
                    .batchId(lineReq.batchId())
                    .build();
            receipt.addLine(line);

            subtotal = subtotal.add(lineAmount);
            totalTax = totalTax.add(lineTax);

            // Build tax line items
            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                allTaxLines.add(TaxLineItem.builder()
                        .orgId(orgId)
                        .sourceType("SALES_RECEIPT")
                        .taxRegime("TAX")
                        .componentCode(comp.rateCode())
                        .rate(comp.percentage())
                        .taxableAmount(lineAmount)
                        .taxAmount(comp.amount())
                        .accountCode(comp.glAccountCode())
                        .hsnCode(lineReq.hsnCode())
                        .baseTaxableAmount(lineAmount)
                        .baseTaxAmount(comp.amount())
                        .build());
            }
        }

        BigDecimal total = subtotal.add(totalTax).setScale(2, RoundingMode.HALF_UP);
        receipt.setSubtotal(subtotal.setScale(2, RoundingMode.HALF_UP));
        receipt.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        receipt.setTotal(total);
        receipt.setChangeReturned(
                request.amountReceived().subtract(total).max(BigDecimal.ZERO)
                        .setScale(2, RoundingMode.HALF_UP));

        // 4. Persist receipt + lines
        receipt = receiptRepository.save(receipt);

        // Save tax line items
        final UUID receiptId = receipt.getId();
        for (TaxLineItem tli : allTaxLines) {
            tli.setSourceId(receiptId);
        }
        taxLineItemRepository.saveAll(allTaxLines);

        // 5. Post journal — immediate payment, no AR
        JournalEntry journalEntry = postJournal(receipt, allTaxLines);
        receipt.setJournalEntryId(journalEntry.getId());
        receiptRepository.save(receipt);

        // 6. Deduct stock for tracked items
        deductStock(receipt, itemMap);

        auditService.log("SALES_RECEIPT", receipt.getId(), "CREATE", null,
                "{\"receiptNumber\":\"" + receiptNumber + "\",\"total\":\"" + total + "\"}");

        return toResponse(receipt);
    }

    @Transactional(readOnly = true)
    public SalesReceiptResponse getById(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesReceipt receipt = receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("SalesReceipt", id));
        return toResponse(receipt);
    }

    @Transactional(readOnly = true)
    public PagedResponse<SalesReceiptResponse> list(UUID branchId, LocalDate dateFrom,
                                                     LocalDate dateTo, String paymentMode,
                                                     Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<SalesReceipt> page = receiptRepository.findFiltered(
                orgId, branchId, dateFrom, dateTo, paymentMode, pageable);
        return PagedResponse.from(page.map(this::toResponse));
    }

    // ── Journal posting ─────────────────────────────────────────

    private JournalEntry postJournal(SalesReceipt receipt, List<TaxLineItem> taxLines) {
        UUID orgId = receipt.getOrgId();
        List<JournalLineRequest> journalLines = new ArrayList<>();

        // DR: Paid-through account (Cash / Bank / UPI)
        String paidThroughCode = resolvePaidThroughAccount(orgId, receipt.getPaymentMode());
        journalLines.add(new JournalLineRequest(
                paidThroughCode,
                receipt.getTotal(),
                BigDecimal.ZERO,
                "POS Sale: " + receipt.getReceiptNumber(),
                null, null));

        // CR: Revenue
        String revenueCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE);
        journalLines.add(new JournalLineRequest(
                revenueCode,
                BigDecimal.ZERO,
                receipt.getSubtotal(),
                "Revenue: " + receipt.getReceiptNumber(),
                null, null));

        // CR: Tax payable per component
        for (TaxLineItem tli : taxLines) {
            if (tli.getAccountCode() == null || tli.getAccountCode().isBlank()) {
                throw new BusinessException(
                        "Tax component " + tli.getComponentCode()
                                + " has no GL output account. Configure it in Settings → Tax Account Mapping.",
                        "TAX_GL_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST);
            }
            journalLines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    BigDecimal.ZERO,
                    tli.getTaxAmount(),
                    tli.getComponentCode() + " Payable",
                    tli.getComponentCode(), null));
        }

        JournalPostRequest journalRequest = new JournalPostRequest(
                receipt.getReceiptDate(),
                "POS Sale " + receipt.getReceiptNumber(),
                "POS",
                receipt.getId(),
                journalLines,
                true);

        return journalService.postJournal(journalRequest);
    }

    private String resolvePaidThroughAccount(UUID orgId, PaymentMode mode) {
        return switch (mode) {
            case CASH -> defaultAccountService.getCode(orgId, DefaultAccountPurpose.CASH);
            case UPI, CARD, MIXED -> defaultAccountService.getCode(orgId, DefaultAccountPurpose.BANK);
        };
    }

    // ── Stock deduction ─────────────────────────────────────────

    private void deductStock(SalesReceipt receipt, Map<UUID, Item> itemMap) {
        UUID orgId = receipt.getOrgId();
        Warehouse warehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElse(null);
        if (warehouse == null) return;

        for (SalesReceiptLine line : receipt.getLines()) {
            if (line.getItemId() == null) continue;
            Item item = itemMap.get(line.getItemId());
            if (item == null || !item.isTrackInventory()) continue;

            UUID batchId = line.getBatchId();
            // FEFO auto-pick if batch-tracked and no explicit batch
            if (item.isTrackBatches() && batchId == null) {
                var batches = batchService.findFefoBatches(item.getId(), warehouse.getId());
                if (!batches.isEmpty()) {
                    batchId = batches.get(0).getId();
                }
            }

            StockMovementRequest req = new StockMovementRequest(
                    line.getItemId(),
                    warehouse.getId(),
                    MovementType.SALE,
                    line.getQuantity().negate(),
                    line.getRate(),
                    receipt.getReceiptDate(),
                    ReferenceType.SALES_RECEIPT,
                    receipt.getId(),
                    receipt.getReceiptNumber(),
                    "POS Sale " + receipt.getReceiptNumber(),
                    batchId);

            StockMovement movement = inventoryService.recordMovement(req);
            line.setStockMovementId(movement.getId());
        }
    }

    // ── Number generation ───────────────────────────────────────

    private String generateNumber(UUID orgId, String prefix, int year) {
        var seqOpt = sequenceRepository.findByOrgIdAndPrefixAndYear(orgId, prefix, year);
        long nextVal;

        if (seqOpt.isPresent()) {
            nextVal = seqOpt.get().getNextValue();
            sequenceRepository.incrementAndGet(orgId, prefix, year);
        } else {
            var seq = InvoiceNumberSequence.builder()
                    .id(new InvoiceNumberSequence.InvoiceNumberSequenceId(orgId, prefix, year))
                    .nextValue(2L)
                    .build();
            sequenceRepository.save(seq);
            nextVal = 1L;
        }

        return String.format("%s-%d-%06d", prefix, year, nextVal);
    }

    // ── Response mapping ────────────────────────────────────────

    public SalesReceiptResponse toResponse(SalesReceipt receipt) {
        UUID orgId = receipt.getOrgId();

        String contactName = null;
        if (receipt.getContactId() != null) {
            contactName = contactRepository.findById(receipt.getContactId())
                    .map(Contact::getDisplayName)
                    .orElse(null);
        }

        // Load items for line enrichment
        List<UUID> itemIds = receipt.getLines().stream()
                .map(SalesReceiptLine::getItemId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        Map<UUID, Item> itemMap = itemIds.isEmpty()
                ? Map.of()
                : itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, itemIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, Function.identity()));

        List<SalesReceiptResponse.LineResponse> lineResponses = receipt.getLines().stream()
                .map(l -> {
                    Item item = l.getItemId() != null ? itemMap.get(l.getItemId()) : null;
                    return new SalesReceiptResponse.LineResponse(
                            l.getId(),
                            l.getLineNumber(),
                            l.getItemId(),
                            item != null ? item.getName() : null,
                            item != null ? item.getSku() : null,
                            l.getDescription(),
                            l.getQuantity(),
                            l.getUnit(),
                            l.getRate(),
                            l.getTaxGroupId(),
                            l.getHsnCode(),
                            l.getAmount(),
                            l.getBatchId());
                })
                .toList();

        return new SalesReceiptResponse(
                receipt.getId(),
                receipt.getReceiptNumber(),
                receipt.getReceiptDate(),
                receipt.getBranchId(),
                receipt.getContactId(),
                contactName,
                receipt.getSubtotal(),
                receipt.getTaxAmount(),
                receipt.getTotal(),
                receipt.getPaymentMode(),
                receipt.getAmountReceived(),
                receipt.getChangeReturned(),
                receipt.getUpiReference(),
                receipt.getNotes(),
                receipt.getJournalEntryId(),
                receipt.getCreatedAt(),
                lineResponses);
    }
}
