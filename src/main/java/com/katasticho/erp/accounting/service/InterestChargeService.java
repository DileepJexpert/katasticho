package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

/**
 * Drafts an interest-claim journal ("interest debit note" in Tally parlance)
 * against an overdue customer invoice — DR {@link DefaultAccountPurpose#AR}
 * / CR {@link DefaultAccountPurpose#INTEREST_INCOME}, using the same simple-
 * interest formula as the overdue-interest report.
 *
 * Posted as DRAFT so collections can review and decide whether to actually
 * claim. Keeps the existing original invoice untouched — the interest is
 * a separate transaction, mirroring how Tally handles interest charges.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class InterestChargeService {

    private final InvoiceRepository invoiceRepository;
    private final JournalService journalService;
    private final DefaultAccountService defaultAccountService;
    private final OrgSettingsService orgSettingsService;

    public record InterestDraftResult(
            UUID invoiceId,
            String invoiceNumber,
            long daysOverdue,
            BigDecimal balanceDue,
            BigDecimal ratePerAnnum,
            BigDecimal interest,
            UUID journalEntryId,
            String journalEntryNumber
    ) {}

    @Transactional
    public InterestDraftResult draftInterestDebitNote(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        LocalDate today = LocalDate.now();
        if (invoice.getDueDate() == null) {
            throw new BusinessException(
                    "Invoice has no due date — cannot compute interest",
                    "INTEREST_NO_DUE_DATE", HttpStatus.BAD_REQUEST);
        }
        long days = ChronoUnit.DAYS.between(invoice.getDueDate(), today);
        if (days <= 0) {
            throw new BusinessException(
                    "Invoice is not overdue (due " + invoice.getDueDate() + ")",
                    "INTEREST_NOT_OVERDUE", HttpStatus.BAD_REQUEST);
        }
        BigDecimal balance = nz(invoice.getBalanceDue());
        if (balance.signum() <= 0) {
            throw new BusinessException(
                    "Invoice has no outstanding balance",
                    "INTEREST_NO_BALANCE", HttpStatus.BAD_REQUEST);
        }

        BigDecimal ratePa = resolveRate(orgId);
        // Simple interest: balance × rate × days / (100 × 365) — same formula
        // as OperationalReportService.overdueInterest() so the report and the
        // posted entry always match to the rupee.
        BigDecimal interest = balance.multiply(ratePa)
                .multiply(BigDecimal.valueOf(days))
                .divide(BigDecimal.valueOf(36500), 2, RoundingMode.HALF_UP);
        if (interest.signum() <= 0) {
            throw new BusinessException(
                    "Computed interest is zero — nothing to draft",
                    "INTEREST_ZERO", HttpStatus.BAD_REQUEST);
        }

        String arCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR);
        String incomeCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.INTEREST_INCOME);

        String description = String.format(
                "Interest on overdue invoice %s — %d days @ %s%% p.a.",
                invoice.getInvoiceNumber(), days, ratePa.toPlainString());

        JournalPostRequest request = new JournalPostRequest(
                today,
                description,
                "INTEREST_CHARGE",
                invoice.getId(),
                List.of(
                        new JournalLineRequest(arCode, interest, BigDecimal.ZERO,
                                "AR: " + invoice.getInvoiceNumber(), null, null),
                        new JournalLineRequest(incomeCode, BigDecimal.ZERO, interest,
                                "Interest income: " + invoice.getInvoiceNumber(), null, null)
                ),
                false);     // autoPost=false → DRAFT for review

        JournalEntry entry = journalService.postJournal(request);
        log.info("Drafted interest charge {} on invoice {} for ₹{} ({} days @ {}%)",
                entry.getEntryNumber(), invoice.getInvoiceNumber(), interest, days, ratePa);

        return new InterestDraftResult(
                invoice.getId(), invoice.getInvoiceNumber(), days, balance,
                ratePa, interest, entry.getId(), entry.getEntryNumber());
    }

    private BigDecimal resolveRate(UUID orgId) {
        try {
            return new BigDecimal(orgSettingsService.get(orgId, "ar.interest_rate_pa", "18"));
        } catch (NumberFormatException e) {
            return new BigDecimal("18");
        }
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
