package com.katasticho.erp.vat;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.CreditNote;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.CreditNoteRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * UAE Federal Tax Authority (FTA) <b>VAT201</b> return aggregator.
 *
 * <p>Quarterly return that every UAE-registered business files via the EmaraTax
 * portal. The simplified shape we compute mirrors the regulator's core boxes:
 * <ul>
 *   <li><b>Box 1a</b> — Standard-rated supplies (taxable amount of outputs).</li>
 *   <li><b>Box 1b</b> — Output VAT (5% of Box 1a in practice).</li>
 *   <li><b>Box 9</b>  — Standard-rated expenses (taxable amount of inputs).</li>
 *   <li><b>Box 10</b> — Recoverable input VAT.</li>
 *   <li><b>Box 14</b> — Net VAT due (1b − 10). Positive = payable, negative = refundable.</li>
 * </ul>
 *
 * <p>Sales-side amounts come from posted invoices in the period, net of credit
 * notes (sales returns). Purchase-side comes from posted vendor bills. Purchase
 * debit notes (purchase returns) are NOT netted yet — they don't have a
 * date-range repository method, and on a typical UAE SMB the impact is small;
 * deferring to a follow-up rather than blocking the basic regulator-shape
 * report. The {@code _meta} block flags this so the accountant sees it.
 *
 * <p>Country-gated by the controller (AE only) — Oman has a near-identical 5%
 * VAT regime that this service will need a {@code omanReturn(...)} sibling for
 * (Oman Tax Authority "VAT Return Form"); deferred to the Oman expansion phase.
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class VatReturnService {

    /** Tax regime stamped on AE/OM tax_line_item rows by the generic engine. */
    private static final String VAT_REGIME = "VAT";

    private final InvoiceRepository invoiceRepository;
    private final CreditNoteRepository creditNoteRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final TaxLineItemRepository taxLineItemRepository;

    /** FTA box rollups for a quarter (or any date window). */
    public record VatReturn(
            LocalDate fromDate,
            LocalDate toDate,
            BigDecimal box1aStandardRatedSupplies,
            BigDecimal box1bOutputVat,
            BigDecimal box9StandardRatedExpenses,
            BigDecimal box10RecoverableInputVat,
            BigDecimal box14NetVatDue,
            Map<String, Object> meta) {
    }

    public VatReturn uaeReturn(LocalDate fromDate, LocalDate toDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (fromDate == null || toDate == null || toDate.isBefore(fromDate)) {
            throw new BusinessException(
                    "Invalid VAT return date range",
                    "VAT_INVALID_RANGE", HttpStatus.BAD_REQUEST);
        }

        List<Invoice> invoices = invoiceRepository.findPostedByOrgAndDateRange(orgId, fromDate, toDate);
        // Sales returns — credit notes excluding DRAFT and CANCELLED so the
        // regulator's payable picture matches what actually moved through AR.
        List<CreditNote> creditNotes = creditNoteRepository
                .findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(
                        orgId, fromDate, toDate, "DRAFT")
                .stream().filter(cn -> !"CANCELLED".equals(cn.getStatus())).toList();
        List<PurchaseBill> bills = purchaseBillRepository.findPostedByOrgAndDateRange(orgId, fromDate, toDate);

        // Single tax_line_item batch fetch for the whole period — the
        // findByOrgAndSourceTypesAndRegimeAndSourceIds query is index-backed.
        Set<UUID> outputIds = new HashSet<>();
        invoices.forEach(i -> outputIds.add(i.getId()));
        creditNotes.forEach(c -> outputIds.add(c.getId()));
        Set<UUID> inputIds = bills.stream().map(PurchaseBill::getId).collect(Collectors.toSet());

        List<TaxLineItem> outputLines = outputIds.isEmpty() ? List.of()
                : taxLineItemRepository.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                        orgId, List.of("INVOICE", "CREDIT_NOTE"), VAT_REGIME, outputIds);
        List<TaxLineItem> inputLines = inputIds.isEmpty() ? List.of()
                : taxLineItemRepository.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                        orgId, List.of("BILL"), VAT_REGIME, inputIds);

        BigDecimal box1a = BigDecimal.ZERO;
        BigDecimal box1b = BigDecimal.ZERO;
        for (TaxLineItem t : outputLines) {
            // Credit notes net against output — taxable_amount and tax_amount are
            // stored positive on the credit note rows, so subtract them out.
            boolean isReturn = "CREDIT_NOTE".equals(t.getSourceType());
            box1a = isReturn ? box1a.subtract(t.getTaxableAmount()) : box1a.add(t.getTaxableAmount());
            box1b = isReturn ? box1b.subtract(t.getTaxAmount()) : box1b.add(t.getTaxAmount());
        }

        BigDecimal box9 = BigDecimal.ZERO;
        BigDecimal box10 = BigDecimal.ZERO;
        for (TaxLineItem t : inputLines) {
            box9 = box9.add(t.getTaxableAmount());
            box10 = box10.add(t.getTaxAmount());
        }

        BigDecimal box14 = box1b.subtract(box10);

        Map<String, Object> meta = new LinkedHashMap<>();
        meta.put("invoiceCount", invoices.size());
        meta.put("creditNoteCount", creditNotes.size());
        meta.put("billCount", bills.size());
        meta.put("outputLineCount", outputLines.size());
        meta.put("inputLineCount", inputLines.size());
        meta.put("debitNotesIncluded", false);
        meta.put("note", "Purchase debit notes are not yet netted into Box 10 — "
                + "manually adjust if returns to suppliers are material this period.");

        return new VatReturn(fromDate, toDate, box1a, box1b, box9, box10, box14, meta);
    }
}
