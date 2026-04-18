package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.*;
import com.katasticho.erp.ar.entity.*;
import com.katasticho.erp.ar.repository.*;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
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
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Credit note lifecycle: DRAFT → ISSUED (posts reversal journal) → APPLIED → CANCELLED
 *
 * On issueCreditNote():
 *   DR Revenue (4010 etc.) = line amounts (reversal of original invoice revenue)
 *   DR GST Payable (2020/2021/2022) = tax amounts (reversal of original tax)
 *   CR Accounts Receivable (1200) = total amount (reduces AR balance)
 *
 * All financial writes go through journalService.postJournal().
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CreditNoteService {

    private final CreditNoteRepository creditNoteRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final ContactRepository contactRepository;
    private final InvoiceRepository invoiceRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final OrganisationRepository organisationRepository;
    private final InvoiceService invoiceService;
    private final JournalService journalService;
    private final TaxEngine taxEngine;
    private final CurrencyService currencyService;
    private final AuditService auditService;
    private final InventoryService inventoryService;
    private final CommentService commentService;
    private final DefaultAccountService defaultAccountService;

    /**
     * Create a DRAFT credit note with tax calculation.
     */
    @Transactional
    public CreditNote createCreditNote(CreateCreditNoteRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));

        Invoice invoice = null;
        if (request.invoiceId() != null) {
            invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(request.invoiceId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Invoice", request.invoiceId()));
        }

        String placeOfSupply = request.placeOfSupply() != null
                ? request.placeOfSupply()
                : contact.getBillingStateCode();

        int periodYear = invoiceService.computeFiscalYear(request.creditNoteDate(), org.getFiscalYearStart());
        String cnNumber = invoiceService.generateNumber(orgId, "CN", periodYear);
        BigDecimal exchangeRate = currencyService.getRate("INR", org.getBaseCurrency(), request.creditNoteDate());

        CreditNote cn = CreditNote.builder()
                .orgId(orgId)
                .contactId(contact.getId())
                .invoiceId(request.invoiceId())
                .creditNoteNumber(cnNumber)
                .creditNoteDate(request.creditNoteDate())
                .reason(request.reason())
                .status("DRAFT")
                .currency("INR")
                .exchangeRate(exchangeRate)
                .placeOfSupply(placeOfSupply)
                .createdBy(userId)
                .build();

        BigDecimal totalSubtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();

        for (int i = 0; i < request.lines().size(); i++) {
            CreditNoteLineRequest lineReq = request.lines().get(i);

            BigDecimal taxableAmount = lineReq.quantity().multiply(lineReq.unitPrice())
                    .setScale(2, RoundingMode.HALF_UP);

            // Resolve tax group: prefer explicit taxGroupId, else resolve from legacy gstRate
            UUID lineTaxGroupId = lineReq.taxGroupId();
            if (lineTaxGroupId == null && lineReq.gstRate() != null
                    && lineReq.gstRate().compareTo(BigDecimal.ZERO) > 0) {
                lineTaxGroupId = taxEngine.resolveGroupId(orgId, lineReq.gstRate(),
                        org.getStateCode(), placeOfSupply).orElse(null);
            }

            TaxEngine.TaxCalculationResult taxResult = taxEngine.calculate(
                    orgId, lineTaxGroupId, taxableAmount, TaxEngine.TransactionType.SALE);

            BigDecimal lineTax = taxResult.totalTaxAmount();
            BigDecimal lineTotal = taxableAmount.add(lineTax);

            BigDecimal baseTaxable = taxableAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTax = lineTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTotal = lineTotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

            CreditNoteLine line = CreditNoteLine.builder()
                    .lineNumber(i + 1)
                    .description(lineReq.description())
                    .hsnCode(lineReq.hsnCode())
                    .quantity(lineReq.quantity())
                    .unitPrice(lineReq.unitPrice())
                    .taxableAmount(taxableAmount)
                    .gstRate(lineReq.gstRate())
                    .taxGroupId(lineTaxGroupId)
                    .taxAmount(lineTax)
                    .lineTotal(lineTotal)
                    .accountCode(lineReq.accountCode())
                    .itemId(lineReq.itemId())
                    .batchId(lineReq.batchId())
                    .baseTaxableAmount(baseTaxable)
                    .baseTaxAmount(baseTax)
                    .baseLineTotal(baseTotal)
                    .build();

            cn.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);

            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                allTaxLines.add(TaxLineItem.builder()
                        .orgId(orgId)
                        .sourceType("CREDIT_NOTE")
                        .taxRegime("TAX")
                        .componentCode(comp.rateCode())
                        .rate(comp.percentage())
                        .taxableAmount(taxableAmount)
                        .taxAmount(comp.amount())
                        .accountCode(comp.glAccountCode())
                        .hsnCode(lineReq.hsnCode())
                        .baseTaxableAmount(baseTaxable)
                        .baseTaxAmount(comp.amount().multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP))
                        .build());
            }
        }

        BigDecimal totalAmount = totalSubtotal.add(totalTax);
        cn.setSubtotal(totalSubtotal.setScale(2, RoundingMode.HALF_UP));
        cn.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        cn.setTotalAmount(totalAmount.setScale(2, RoundingMode.HALF_UP));
        cn.setBaseSubtotal(totalSubtotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        cn.setBaseTaxAmount(totalTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        cn.setBaseTotal(totalAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));

        cn = creditNoteRepository.save(cn);

        final UUID cnId = cn.getId();
        allTaxLines.forEach(tli -> tli.setSourceId(cnId));
        taxLineItemRepository.saveAll(allTaxLines);

        auditService.log("CREDIT_NOTE", cn.getId(), "CREATE", null,
                "{\"creditNoteNumber\":\"" + cn.getCreditNoteNumber() + "\",\"total\":\"" + cn.getTotalAmount() + "\"}");

        commentService.addSystemComment("CREDIT_NOTE", cn.getId(), "Credit note created");

        log.info("Credit note {} created: total={}", cn.getCreditNoteNumber(), cn.getTotalAmount());
        return cn;
    }

    /**
     * Issue credit note: DRAFT → ISSUED. Posts reversal journal.
     *
     * Journal mapping (reverse of invoice):
     *   DR Revenue (4010 etc.) = line taxable amounts
     *   DR GST Payable (2020/2021/2022) = tax amounts
     *   CR Accounts Receivable (1200) = total amount
     */
    @Transactional
    public CreditNote issueCreditNote(UUID creditNoteId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        CreditNote cn = creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(creditNoteId, orgId)
                .orElseThrow(() -> BusinessException.notFound("CreditNote", creditNoteId));

        if (!"DRAFT".equals(cn.getStatus())) {
            throw new BusinessException("Only DRAFT credit notes can be issued",
                    "AR_CN_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        List<JournalLineRequest> journalLines = new ArrayList<>();

        // DR: Revenue reversal per line
        for (CreditNoteLine line : cn.getLines()) {
            journalLines.add(new JournalLineRequest(
                    line.getAccountCode(),
                    line.getTaxableAmount(), BigDecimal.ZERO,
                    "CN Revenue reversal: " + line.getDescription(),
                    null, null));
        }

        // DR: Tax reversal per component
        List<TaxLineItem> taxLines = taxLineItemRepository.findBySourceTypeAndSourceId("CREDIT_NOTE", cn.getId());
        for (TaxLineItem tli : taxLines) {
            journalLines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    tli.getTaxAmount(), BigDecimal.ZERO,
                    tli.getComponentCode() + " reversal",
                    tli.getComponentCode(), null));
        }

        // CR: Accounts Receivable (per-org default)
        journalLines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                BigDecimal.ZERO, cn.getTotalAmount(),
                "AR credit: CN " + cn.getCreditNoteNumber(),
                null, null));

        JournalPostRequest journalRequest = new JournalPostRequest(
                cn.getCreditNoteDate(),
                "Credit Note " + cn.getCreditNoteNumber(),
                "AR",
                cn.getId(),
                journalLines,
                true);

        JournalEntry journalEntry = journalService.postJournal(journalRequest);

        // Restore stock for any itemised lines (returns / damages refunded).
        // For batch-tracked items the line MUST carry the batch_id of the
        // returned goods — the inventory gate rejects auto-picking on restore.
        for (CreditNoteLine line : cn.getLines()) {
            if (line.getItemId() != null) {
                inventoryService.restoreStockForCreditNote(
                        orgId,
                        line.getItemId(),
                        line.getQuantity(),
                        line.getUnitPrice(),
                        cn.getId(),
                        cn.getCreditNoteNumber(),
                        cn.getCreditNoteDate(),
                        line.getBatchId());
            }
        }

        cn.setStatus("ISSUED");
        cn.setJournalEntryId(journalEntry.getId());
        cn = creditNoteRepository.save(cn);

        // If linked to invoice, reduce balance due
        if (cn.getInvoiceId() != null) {
            Invoice invoice = invoiceRepository.findById(cn.getInvoiceId()).orElse(null);
            if (invoice != null) {
                invoiceService.updatePaymentStatus(invoice, cn.getTotalAmount());
                cn.setStatus("APPLIED");
                cn = creditNoteRepository.save(cn);
            }
        }

        auditService.log("CREDIT_NOTE", cn.getId(), "ISSUE", "{\"status\":\"DRAFT\"}",
                "{\"status\":\"" + cn.getStatus() + "\",\"journalEntryId\":\"" + journalEntry.getId() + "\"}");

        log.info("Credit note {} issued, journal={}", cn.getCreditNoteNumber(), journalEntry.getEntryNumber());
        return cn;
    }

    public CreditNote getCreditNote(UUID creditNoteId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(creditNoteId, orgId)
                .orElseThrow(() -> BusinessException.notFound("CreditNote", creditNoteId));
    }

    public Page<CreditNote> listCreditNotes(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return creditNoteRepository.findByOrgIdAndIsDeletedFalseOrderByCreditNoteDateDesc(orgId, pageable);
    }

    public CreditNoteResponse toResponse(CreditNote cn) {
        Contact contact = contactRepository.findById(cn.getContactId()).orElse(null);
        Invoice invoice = cn.getInvoiceId() != null ? invoiceRepository.findById(cn.getInvoiceId()).orElse(null) : null;

        List<CreditNoteResponse.LineResponse> lineResponses = cn.getLines().stream()
                .map(l -> new CreditNoteResponse.LineResponse(
                        l.getId(), l.getLineNumber(), l.getDescription(), l.getHsnCode(),
                        l.getQuantity(), l.getUnitPrice(), l.getTaxableAmount(),
                        l.getGstRate(), l.getTaxAmount(), l.getLineTotal(), l.getAccountCode()))
                .toList();

        return new CreditNoteResponse(
                cn.getId(), cn.getContactId(),
                contact != null ? contact.getDisplayName() : null,
                cn.getInvoiceId(),
                invoice != null ? invoice.getInvoiceNumber() : null,
                cn.getCreditNoteNumber(), cn.getCreditNoteDate(),
                cn.getReason(), cn.getStatus(),
                cn.getSubtotal(), cn.getTaxAmount(), cn.getTotalAmount(),
                cn.getCurrency(), cn.getPlaceOfSupply(),
                cn.getJournalEntryId(), lineResponses, cn.getCreatedAt());
    }
}
