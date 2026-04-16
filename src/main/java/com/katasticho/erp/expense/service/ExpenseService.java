package com.katasticho.erp.expense.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.expense.dto.CreateExpenseRequest;
import com.katasticho.erp.expense.dto.ExpenseResponse;
import com.katasticho.erp.expense.dto.UpdateExpenseRequest;
import com.katasticho.erp.expense.entity.Expense;
import com.katasticho.erp.expense.entity.PaymentMode;
import com.katasticho.erp.expense.repository.ExpenseRepository;
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
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Expense recording — F7.
 *
 * Expense lifecycle:
 *   RECORDED   — saved + journal posted
 *   BILLABLE   — recorded and flagged is_billable (awaiting invoice)
 *   INVOICED   — billable expense has been added to a customer invoice
 *   VOID       — reversed via reversal journal
 *
 * All financial writes go through JournalService.postJournal().
 *
 * Journal mapping on create:
 *   DR  Expense GL (accountId)        amount
 *   DR  GST Input Credit (1500)       tax_amount   (if gstRate > 0)
 *   CR  Paid-through (paidThroughId)  total
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ExpenseService {

    private final ExpenseRepository expenseRepository;
    private final AccountRepository accountRepository;
    private final ContactRepository contactRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final OrganisationRepository organisationRepository;
    private final JournalService journalService;
    private final TaxEngine taxEngine;
    private final TaxLineItemRepository taxLineItemRepository;
    private final AuditService auditService;
    private final CommentService commentService;

    // ─────────────────────────────────────────────────────────────
    // CREATE
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public ExpenseResponse createExpense(CreateExpenseRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        validatePaymentMode(request.paymentMode());

        Account expenseAccount = requireAccount(orgId, request.accountId(), "Expense account");
        Account paidThrough = requireAccount(orgId, request.paidThroughId(), "Paid-through account");

        // Validate vendor (optional)
        if (request.contactId() != null) {
            contactRepository.findById(request.contactId())
                    .filter(c -> orgId.equals(c.getOrgId()) && !c.isDeleted())
                    .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));
        }

        BigDecimal amount = request.amount().setScale(2, RoundingMode.HALF_UP);
        BigDecimal gstRate = request.gstRate() != null ? request.gstRate() : BigDecimal.ZERO;

        // Resolve tax group: prefer explicit taxGroupId, else resolve from legacy gstRate
        UUID taxGroupId = request.taxGroupId();
        if (taxGroupId == null && gstRate.compareTo(BigDecimal.ZERO) > 0) {
            taxGroupId = taxEngine.resolveGroupId(orgId, gstRate, org.getStateCode(), org.getStateCode())
                    .orElse(null);
        }

        TaxEngine.TaxCalculationResult taxResult = taxEngine.calculate(
                orgId, taxGroupId, amount, TaxEngine.TransactionType.PURCHASE);

        BigDecimal taxAmount = taxResult.totalTaxAmount();
        BigDecimal total = amount.add(taxAmount);

        int periodYear = computeFiscalYear(request.expenseDate(), org.getFiscalYearStart());
        String expenseNumber = generateNumber(orgId, "EXP", periodYear);

        String status = request.billable() ? "BILLABLE" : "RECORDED";

        Expense expense = Expense.builder()
                .orgId(orgId)
                .expenseNumber(expenseNumber)
                .expenseDate(request.expenseDate())
                .accountId(expenseAccount.getId())
                .category(request.category())
                .description(request.description())
                .amount(amount)
                .taxAmount(taxAmount)
                .total(total)
                .currency(request.currency() != null ? request.currency() : "INR")
                .gstRate(gstRate)
                .taxGroupId(taxGroupId)
                .contactId(request.contactId())
                .paymentMode(request.paymentMode())
                .paidThroughId(paidThrough.getId())
                .billable(request.billable())
                .projectId(request.projectId())
                .customerContactId(request.customerContactId())
                .receiptUrl(request.receiptUrl())
                .status(status)
                .createdBy(userId)
                .build();

        // Post journal FIRST, then save expense with journal ref.
        JournalEntry journalEntry = postExpenseJournal(
                expense, expenseAccount, paidThrough, taxResult, "Expense " + expenseNumber);
        expense.setJournalEntryId(journalEntry.getId());

        expense = expenseRepository.save(expense);

        // Save tax line items
        saveTaxLineItems(orgId, expense.getId(), taxResult);

        auditService.log("EXPENSE", expense.getId(), "CREATE", null,
                "{\"expenseNumber\":\"" + expense.getExpenseNumber()
                        + "\",\"total\":\"" + expense.getTotal() + "\"}");

        commentService.addSystemComment("EXPENSE", expense.getId(), "Expense recorded");

        log.info("Expense {} created: total={} journal={}",
                expense.getExpenseNumber(), expense.getTotal(), journalEntry.getEntryNumber());
        return toResponse(expense);
    }

    // ─────────────────────────────────────────────────────────────
    // UPDATE
    // ─────────────────────────────────────────────────────────────
    /**
     * Updates a RECORDED / BILLABLE expense. If any financial field changes
     * (amount, gstRate, account, paid-through), the existing journal is
     * reversed and a new one is posted.
     */
    @Transactional
    public ExpenseResponse updateExpense(UUID expenseId, UpdateExpenseRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Expense expense = expenseRepository.findByIdAndOrgIdAndIsDeletedFalse(expenseId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Expense", expenseId));

        if ("VOID".equals(expense.getStatus()) || "INVOICED".equals(expense.getStatus())) {
            throw new BusinessException(
                    "Cannot update " + expense.getStatus() + " expense",
                    "EXP_UPDATE_INVALID", HttpStatus.BAD_REQUEST);
        }

        boolean financialChange = false;

        if (request.expenseDate() != null) {
            expense.setExpenseDate(request.expenseDate());
            financialChange = true;
        }
        if (request.accountId() != null && !request.accountId().equals(expense.getAccountId())) {
            requireAccount(orgId, request.accountId(), "Expense account");
            expense.setAccountId(request.accountId());
            financialChange = true;
        }
        if (request.paidThroughId() != null && !request.paidThroughId().equals(expense.getPaidThroughId())) {
            requireAccount(orgId, request.paidThroughId(), "Paid-through account");
            expense.setPaidThroughId(request.paidThroughId());
            financialChange = true;
        }
        if (request.amount() != null) {
            expense.setAmount(request.amount().setScale(2, RoundingMode.HALF_UP));
            financialChange = true;
        }
        if (request.gstRate() != null) {
            expense.setGstRate(request.gstRate());
            financialChange = true;
        }
        if (request.paymentMode() != null) {
            validatePaymentMode(request.paymentMode());
            expense.setPaymentMode(request.paymentMode());
        }
        if (request.category() != null) expense.setCategory(request.category());
        if (request.description() != null) expense.setDescription(request.description());
        if (request.contactId() != null) expense.setContactId(request.contactId());
        if (request.projectId() != null) expense.setProjectId(request.projectId());
        if (request.customerContactId() != null) expense.setCustomerContactId(request.customerContactId());
        if (request.receiptUrl() != null) expense.setReceiptUrl(request.receiptUrl());
        if (request.billable() != null) {
            expense.setBillable(request.billable());
            expense.setStatus(request.billable() ? "BILLABLE" : "RECORDED");
        }

        if (financialChange) {
            // Resolve tax group
            UUID updTaxGroupId = expense.getTaxGroupId();
            if (request.taxGroupId() != null) {
                updTaxGroupId = request.taxGroupId();
                expense.setTaxGroupId(updTaxGroupId);
            }
            if (updTaxGroupId == null && expense.getGstRate().compareTo(BigDecimal.ZERO) > 0) {
                Organisation updOrg = organisationRepository.findById(orgId)
                        .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
                updTaxGroupId = taxEngine.resolveGroupId(orgId, expense.getGstRate(),
                        updOrg.getStateCode(), updOrg.getStateCode()).orElse(null);
                expense.setTaxGroupId(updTaxGroupId);
            }

            // Recompute tax via tax engine
            TaxEngine.TaxCalculationResult updTaxResult = taxEngine.calculate(
                    orgId, updTaxGroupId, expense.getAmount(), TaxEngine.TransactionType.PURCHASE);
            expense.setTaxAmount(updTaxResult.totalTaxAmount());
            expense.setTotal(expense.getAmount().add(updTaxResult.totalTaxAmount()));

            // Reverse old journal, post new one
            if (expense.getJournalEntryId() != null) {
                journalService.reverseEntry(expense.getJournalEntryId());
            }
            Account expenseAccount = requireAccount(orgId, expense.getAccountId(), "Expense account");
            Account paidThrough = requireAccount(orgId, expense.getPaidThroughId(), "Paid-through account");
            JournalEntry newJe = postExpenseJournal(
                    expense, expenseAccount, paidThrough, updTaxResult,
                    "Expense " + expense.getExpenseNumber() + " (updated)");
            expense.setJournalEntryId(newJe.getId());

            // Re-save tax line items
            taxLineItemRepository.deleteBySourceTypeAndSourceId("EXPENSE", expense.getId());
            saveTaxLineItems(orgId, expense.getId(), updTaxResult);
        }

        expense = expenseRepository.save(expense);

        auditService.log("EXPENSE", expense.getId(), "UPDATE", null,
                "{\"total\":\"" + expense.getTotal() + "\"}");
        commentService.addSystemComment("EXPENSE", expense.getId(),
                financialChange ? "Expense updated (journal re-posted)" : "Expense updated");

        return toResponse(expense);
    }

    // ─────────────────────────────────────────────────────────────
    // VOID
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public ExpenseResponse voidExpense(UUID expenseId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Expense expense = expenseRepository.findByIdAndOrgIdAndIsDeletedFalse(expenseId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Expense", expenseId));

        if ("VOID".equals(expense.getStatus())) {
            throw new BusinessException("Expense already void", "EXP_ALREADY_VOID", HttpStatus.BAD_REQUEST);
        }
        if ("INVOICED".equals(expense.getStatus())) {
            throw new BusinessException(
                    "Cannot void an invoiced expense — issue a credit note on the source invoice",
                    "EXP_VOID_INVOICED", HttpStatus.BAD_REQUEST);
        }

        if (expense.getJournalEntryId() != null) {
            journalService.reverseEntry(expense.getJournalEntryId());
        }
        expense.setStatus("VOID");
        expense = expenseRepository.save(expense);

        auditService.log("EXPENSE", expense.getId(), "VOID", null,
                "{\"reason\":\"" + (reason != null ? reason : "") + "\"}");
        commentService.addSystemComment("EXPENSE", expense.getId(),
                "Expense voided" + (reason != null && !reason.isBlank() ? ": " + reason : ""));

        log.info("Expense {} voided", expense.getExpenseNumber());
        return toResponse(expense);
    }

    // ─────────────────────────────────────────────────────────────
    // READ
    // ─────────────────────────────────────────────────────────────
    @Transactional(readOnly = true)
    public ExpenseResponse getExpense(UUID expenseId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Expense expense = expenseRepository.findByIdAndOrgIdAndIsDeletedFalse(expenseId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Expense", expenseId));
        return toResponse(expense);
    }

    @Transactional(readOnly = true)
    public Page<ExpenseResponse> listExpenses(LocalDate from, LocalDate to, String category,
                                              UUID contactId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Page<Expense> page;
        if (contactId != null) {
            page = expenseRepository
                    .findByOrgIdAndContactIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
                            orgId, contactId, pageable);
        } else if (from != null && to != null && category != null) {
            page = expenseRepository
                    .findByOrgIdAndExpenseDateBetweenAndCategoryAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
                            orgId, from, to, category, pageable);
        } else if (from != null && to != null) {
            page = expenseRepository
                    .findByOrgIdAndExpenseDateBetweenAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
                            orgId, from, to, pageable);
        } else if (category != null) {
            page = expenseRepository
                    .findByOrgIdAndCategoryAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
                            orgId, category, pageable);
        } else {
            page = expenseRepository
                    .findByOrgIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(orgId, pageable);
        }
        return page.map(this::toResponse);
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────
    private JournalEntry postExpenseJournal(Expense expense,
                                            Account expenseAccount,
                                            Account paidThrough,
                                            TaxEngine.TaxCalculationResult taxResult,
                                            String description) {
        List<JournalLineRequest> lines = new ArrayList<>();

        // DR: Expense GL = amount (pre-tax)
        lines.add(new JournalLineRequest(
                expenseAccount.getCode(),
                expense.getAmount(),
                BigDecimal.ZERO,
                description,
                null, null));

        // DR: Tax input credit per component (account code from tax engine)
        for (TaxEngine.TaxComponent comp : taxResult.components()) {
            if (comp.glAccountCode() == null) continue; // non-recoverable tax
            lines.add(new JournalLineRequest(
                    comp.glAccountCode(),
                    comp.amount(),
                    BigDecimal.ZERO,
                    comp.rateCode() + " Input Credit: " + expense.getExpenseNumber(),
                    null, null));
        }

        // CR: Paid-through (Cash / Bank) = total
        lines.add(new JournalLineRequest(
                paidThrough.getCode(),
                BigDecimal.ZERO,
                expense.getTotal(),
                paidThrough.getName() + ": " + expense.getExpenseNumber(),
                null, null));

        JournalPostRequest request = new JournalPostRequest(
                expense.getExpenseDate(),
                description,
                "EXPENSE",
                null,          // sourceId set after save — journal is standalone-safe
                lines,
                true);
        return journalService.postJournal(request);
    }

    private void saveTaxLineItems(UUID orgId, UUID expenseId, TaxEngine.TaxCalculationResult taxResult) {
        List<TaxLineItem> taxLines = new ArrayList<>();
        for (TaxEngine.TaxComponent comp : taxResult.components()) {
            if (comp.glAccountCode() == null) continue;
            taxLines.add(TaxLineItem.builder()
                    .orgId(orgId)
                    .sourceType("EXPENSE")
                    .sourceId(expenseId)
                    .taxRegime("TAX")
                    .componentCode(comp.rateCode())
                    .rate(comp.percentage())
                    .taxableAmount(BigDecimal.ZERO) // expense has single amount, not per-line
                    .taxAmount(comp.amount())
                    .accountCode(comp.glAccountCode())
                    .build());
        }
        if (!taxLines.isEmpty()) {
            taxLineItemRepository.saveAll(taxLines);
        }
    }

    private Account requireAccount(UUID orgId, UUID accountId, String label) {
        return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId)
                .orElseThrow(() -> new BusinessException(
                        label + " not found: " + accountId,
                        "EXP_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
    }

    private void validatePaymentMode(String mode) {
        try {
            PaymentMode.valueOf(mode);
        } catch (IllegalArgumentException e) {
            throw new BusinessException(
                    "Invalid payment mode: " + mode,
                    "EXP_BAD_PAYMENT_MODE", HttpStatus.BAD_REQUEST);
        }
    }

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

    private int computeFiscalYear(LocalDate date, int fiscalYearStartMonth) {
        return date.getMonthValue() >= fiscalYearStartMonth ? date.getYear() : date.getYear() - 1;
    }

    private ExpenseResponse toResponse(Expense e) {
        Account account = accountRepository.findById(e.getAccountId()).orElse(null);
        Account paidThrough = accountRepository.findById(e.getPaidThroughId()).orElse(null);

        String contactName = null;
        if (e.getContactId() != null) {
            Contact c = contactRepository.findById(e.getContactId()).orElse(null);
            if (c != null) contactName = c.getDisplayName();
        }
        String customerContactName = null;
        if (e.getCustomerContactId() != null) {
            Contact c = contactRepository.findById(e.getCustomerContactId()).orElse(null);
            if (c != null) customerContactName = c.getDisplayName();
        }

        return new ExpenseResponse(
                e.getId(),
                e.getExpenseNumber(),
                e.getExpenseDate(),
                e.getAccountId(),
                account != null ? account.getCode() : null,
                account != null ? account.getName() : null,
                e.getCategory(),
                e.getDescription(),
                e.getAmount(),
                e.getTaxAmount(),
                e.getTotal(),
                e.getCurrency(),
                e.getGstRate(),
                e.getContactId(),
                contactName,
                e.getPaymentMode(),
                e.getPaidThroughId(),
                paidThrough != null ? paidThrough.getName() : null,
                e.isBillable(),
                e.getProjectId(),
                e.getCustomerContactId(),
                customerContactName,
                e.getReceiptUrl(),
                e.getStatus(),
                e.getJournalEntryId(),
                e.getCreatedAt());
    }
}
