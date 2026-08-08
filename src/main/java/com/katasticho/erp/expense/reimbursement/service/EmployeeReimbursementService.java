package com.katasticho.erp.expense.reimbursement.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.expense.dto.CreateExpenseRequest;
import com.katasticho.erp.expense.reimbursement.dto.*;
import com.katasticho.erp.expense.reimbursement.entity.EmployeeExpenseAdvance;
import com.katasticho.erp.expense.reimbursement.entity.EmployeeExpenseReimbursement;
import com.katasticho.erp.expense.reimbursement.entity.EmployeeReimbursementAdvanceAllocation;
import com.katasticho.erp.expense.reimbursement.repository.*;
import com.katasticho.erp.expense.service.ExpenseService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class EmployeeReimbursementService {
    private static final String ADVANCE_CODE = DefaultAccountPurpose.EMPLOYEE_ADVANCE.defaultCode();
    private static final String PAYABLE_CODE = DefaultAccountPurpose.EMPLOYEE_REIMBURSEMENT_PAYABLE.defaultCode();

    private final EmployeeExpenseReimbursementRepository reimbursementRepository;
    private final EmployeeExpenseAdvanceRepository advanceRepository;
    private final EmployeeReimbursementAdvanceAllocationRepository allocationRepository;
    private final EmployeeRepository employeeRepository;
    private final AccountRepository accountRepository;
    private final DefaultAccountService defaultAccountService;
    private final ExpenseService expenseService;
    private final JournalService journalService;
    private final AuditService auditService;
    private final CommentService commentService;

    @Transactional
    public ReimbursementResponse submit(CreateReimbursementRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID employeeId = request.employeeId();
        if (employeeId == null) {
            employeeId = employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, TenantContext.getCurrentUserId())
                    .map(Employee::getId)
                    .orElseThrow(() -> new BusinessException(
                            "No employee profile is linked to the logged-in user",
                            "REIMBURSEMENT_EMPLOYEE_REQUIRED", HttpStatus.BAD_REQUEST));
        }
        requireEmployee(orgId, employeeId);
        Account expenseAccount = requireAccount(orgId, request.accountId(), "Expense account");
        if (!"EXPENSE".equals(expenseAccount.getType())) {
            throw new BusinessException("Reimbursement account must be an expense account",
                    "REIMBURSEMENT_ACCOUNT_INVALID", HttpStatus.BAD_REQUEST);
        }

        BigDecimal amount = money(request.amount());
        EmployeeExpenseReimbursement claim = EmployeeExpenseReimbursement.builder()
                
                .employeeId(employeeId)
                .expenseDate(request.expenseDate())
                .accountId(expenseAccount.getId())
                .category(request.category())
                .description(request.description())
                .amount(amount)
                .payableAmount(amount)
                .receiptUrl(request.receiptUrl())
                .notes(request.notes())
                .build();
        claim.setOrgId(orgId);
        claim = reimbursementRepository.save(claim);
        auditService.log("EMPLOYEE_REIMBURSEMENT", claim.getId(), "SUBMIT", null,
                "{\"amount\":\"" + amount + "\",\"employeeId\":\"" + employeeId + "\"}");
        commentService.addSystemComment("EMPLOYEE_REIMBURSEMENT", claim.getId(), "Reimbursement submitted");
        return toResponse(claim);
    }

    @Transactional
    public EmployeeAdvanceResponse createAdvance(CreateEmployeeAdvanceRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        requireEmployee(orgId, request.employeeId());
        Account paidThrough = requireAccount(orgId, request.paidThroughId(), "Paid-through account");
        Account advanceAccount = ensureAccount(orgId, ADVANCE_CODE, "Employee Advances", "ASSET", "CURRENT_ASSET", "1000");
        BigDecimal amount = money(request.amount());
        JournalEntry journal = journalService.postJournal(new JournalPostRequest(
                request.advanceDate(), "Employee advance", "EMPLOYEE_ADVANCE", null,
                List.of(
                        line(advanceAccount.getCode(), amount, BigDecimal.ZERO, "Advance to employee"),
                        line(paidThrough.getCode(), BigDecimal.ZERO, amount, "Advance paid")
                ), true));
        EmployeeExpenseAdvance advance = EmployeeExpenseAdvance.builder()
                .employeeId(request.employeeId()).advanceDate(request.advanceDate())
                .amount(amount).paidThroughId(paidThrough.getId()).journalEntryId(journal.getId())
                .notes(request.notes()).build();
        advance.setOrgId(orgId);
        advance = advanceRepository.save(advance);
        auditService.log("EMPLOYEE_ADVANCE", advance.getId(), "CREATE", null,
                "{\"amount\":\"" + amount + "\",\"employeeId\":\"" + request.employeeId() + "\"}");
        return toAdvanceResponse(advance);
    }

    @Transactional
    public ReimbursementResponse approve(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeExpenseReimbursement claim = requireClaim(orgId, id);
        ensureApproverIsNotSubmitter(claim);
        if (!"SUBMITTED".equals(claim.getStatus())) {
            throw invalidStatus("Only submitted reimbursements can be approved");
        }
        Account payable = ensureAccount(orgId, PAYABLE_CODE, "Employee Reimbursement Payable", "LIABILITY", "CURRENT_LIABILITY", "2000");
        CreateExpenseRequest expenseRequest = new CreateExpenseRequest(
                claim.getExpenseDate(), claim.getAccountId(), claim.getCategory(), claim.getDescription(),
                claim.getAmount(), BigDecimal.ZERO, "INR", null, "EMPLOYEE_PAYABLE", payable.getId(),
                false, null, null, claim.getReceiptUrl(), null, claim.getEmployeeId());
        var expense = expenseService.createExpense(expenseRequest);
        claim.setExpenseId(expense.id());
        claim.setStatus("APPROVED");
        claim.setApprovedBy(TenantContext.getCurrentUserId());
        claim.setApprovedAt(Instant.now());
        claim.setPayableAmount(claim.getAmount());
        allocateAdvances(claim, payable);
        claim.setOrgId(orgId);
        claim = reimbursementRepository.save(claim);
        auditService.log("EMPLOYEE_REIMBURSEMENT", claim.getId(), "APPROVE", null,
                "{\"expenseId\":\"" + expense.id() + "\",\"advanceApplied\":\"" + claim.getAdvanceApplied() + "\"}");
        commentService.addSystemComment("EMPLOYEE_REIMBURSEMENT", claim.getId(), "Reimbursement approved");
        return toResponse(claim);
    }

    @Transactional
    public ReimbursementResponse reject(UUID id, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeExpenseReimbursement claim = requireClaim(orgId, id);
        ensureApproverIsNotSubmitter(claim);
        if (!"SUBMITTED".equals(claim.getStatus())) throw invalidStatus("Only submitted reimbursements can be rejected");
        claim.setStatus("REJECTED");
        claim.setRejectedBy(TenantContext.getCurrentUserId());
        claim.setRejectedAt(Instant.now());
        claim.setRejectionReason(reason);
        claim.setOrgId(orgId);
        claim = reimbursementRepository.save(claim);
        auditService.log("EMPLOYEE_REIMBURSEMENT", id, "REJECT", null, "{\"reason\":\"" + safe(reason) + "\"}");
        commentService.addSystemComment("EMPLOYEE_REIMBURSEMENT", id, "Reimbursement rejected: " + reason);
        return toResponse(claim);
    }

    @Transactional
    public ReimbursementResponse pay(UUID id, PayReimbursementRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeExpenseReimbursement claim = requireClaim(orgId, id);
        if (!"APPROVED".equals(claim.getStatus())) throw invalidStatus("Only approved reimbursements can be paid");
        BigDecimal payable = money(claim.getPayableAmount());
        JournalEntry journal = null;
        if (payable.signum() > 0) {
            Account payableAccount = ensureAccount(orgId, PAYABLE_CODE, "Employee Reimbursement Payable", "LIABILITY", "CURRENT_LIABILITY", "2000");
            Account paidThrough = requireAccount(orgId, request.paidThroughId(), "Paid-through account");
            journal = journalService.postJournal(new JournalPostRequest(
                    LocalDate.now(), "Employee reimbursement payment", "EMPLOYEE_REIMBURSEMENT_PAYMENT", id,
                    List.of(
                            line(payableAccount.getCode(), payable, BigDecimal.ZERO, "Clear employee payable"),
                            line(paidThrough.getCode(), BigDecimal.ZERO, payable, "Pay employee")
                    ), true));
            claim.setPaidThroughId(paidThrough.getId());
            claim.setPaymentJournalEntryId(journal.getId());
        }
        claim.setPaidAmount(payable);
        claim.setPaidAt(Instant.now());
        claim.setStatus("PAID");
        claim.setOrgId(orgId);
        claim = reimbursementRepository.save(claim);
        auditService.log("EMPLOYEE_REIMBURSEMENT", id, "PAY", null,
                "{\"amount\":\"" + payable + "\",\"journalId\":\"" + (journal == null ? "" : journal.getId()) + "\"}");
        commentService.addSystemComment("EMPLOYEE_REIMBURSEMENT", id, "Reimbursement paid");
        return toResponse(claim);
    }

    @Transactional(readOnly = true)
    public Page<ReimbursementResponse> list(String status, UUID employeeId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<EmployeeExpenseReimbursement> page;
        if (employeeId != null) page = reimbursementRepository.findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(orgId, employeeId, pageable);
        else if (status != null) page = reimbursementRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(orgId, status, pageable);
        else page = reimbursementRepository.findByOrgIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(orgId, pageable);
        return page.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public ReimbursementResponse get(UUID id) { return toResponse(requireClaim(TenantContext.getCurrentOrgId(), id)); }

    @Transactional(readOnly = true)
    public Page<EmployeeAdvanceResponse> listAdvances(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return advanceRepository.findByOrgIdAndIsDeletedFalseOrderByAdvanceDateDescCreatedAtDesc(orgId, pageable).map(this::toAdvanceResponse);
    }

    private void allocateAdvances(EmployeeExpenseReimbursement claim, Account payable) {
        UUID orgId = claim.getOrgId();
        BigDecimal remaining = claim.getAmount();
        BigDecimal applied = BigDecimal.ZERO;
        List<EmployeeReimbursementAdvanceAllocation> allocations = new ArrayList<>();
        for (EmployeeExpenseAdvance advance : advanceRepository.findByOrgIdAndEmployeeIdAndStatusAndIsDeletedFalseOrderByAdvanceDateAscCreatedAtAsc(orgId, claim.getEmployeeId(), "OPEN")) {
            BigDecimal open = advance.getAmount().subtract(advance.getSettledAmount());
            if (open.signum() <= 0) continue;
            BigDecimal amount = open.min(remaining);
            advance.setSettledAmount(advance.getSettledAmount().add(amount));
            if (advance.getSettledAmount().compareTo(advance.getAmount()) >= 0) advance.setStatus("SETTLED");
            advanceRepository.save(advance);
            EmployeeReimbursementAdvanceAllocation allocation = EmployeeReimbursementAdvanceAllocation.builder().reimbursementId(claim.getId()).advanceId(advance.getId()).amount(amount).build();
            allocation.setOrgId(orgId);
            allocations.add(allocation);
            applied = applied.add(amount);
            remaining = remaining.subtract(amount);
            if (remaining.signum() <= 0) break;
        }
        if (applied.signum() > 0) {
            Account advanceAccount = ensureAccount(orgId, ADVANCE_CODE, "Employee Advances", "ASSET", "CURRENT_ASSET", "1000");
            JournalEntry journal = journalService.postJournal(new JournalPostRequest(
                    claim.getExpenseDate(), "Settle employee advance against reimbursement", "EMPLOYEE_REIMBURSEMENT_ADVANCE_SETTLEMENT", claim.getId(),
                    List.of(line(payable.getCode(), applied, BigDecimal.ZERO, "Recognize employee amount due"), line(advanceAccount.getCode(), BigDecimal.ZERO, applied, "Use employee advance")), true));
            claim.setSettlementJournalEntryId(journal.getId());
            allocationRepository.saveAll(allocations);
        }
        claim.setAdvanceApplied(applied);
        claim.setPayableAmount(remaining);
    }

    private Account ensureAccount(UUID orgId, String code, String name, String type, String subType, String parentCode) {
        return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code).orElseGet(() -> {
            Account parent = accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, parentCode)
                    .orElseThrow(() -> new BusinessException("Parent account not found: " + parentCode, "REIMBURSEMENT_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST));
            Account account = Account.builder().code(code).name(name).type(type).subType(subType).parentId(parent.getId()).level(2).system(false).description("Employee reimbursement workflow account").build();
            account.setOrgId(orgId);
            Account saved = accountRepository.save(account);
            defaultAccountService.seedDefaultsForOrg(orgId);
            return saved;
        });
    }

    private Account requireAccount(UUID orgId, UUID id, String label) {
        return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, id)
                .orElseThrow(() -> new BusinessException(label + " not found: " + id, "REIMBURSEMENT_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
    }

    private Employee requireEmployee(UUID orgId, UUID id) {
        return employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", id));
    }

    private EmployeeExpenseReimbursement requireClaim(UUID orgId, UUID id) {
        return reimbursementRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee reimbursement", id));
    }

    private void ensureApproverIsNotSubmitter(EmployeeExpenseReimbursement claim) {
        UUID userId = TenantContext.getCurrentUserId();
        if (userId != null && userId.equals(claim.getCreatedBy()))
            throw new BusinessException("The submitter cannot approve or reject their own reimbursement", "REIMBURSEMENT_SELF_APPROVAL", HttpStatus.FORBIDDEN);
    }

    private BusinessException invalidStatus(String message) { return new BusinessException(message, "REIMBURSEMENT_STATUS_INVALID", HttpStatus.BAD_REQUEST); }
    private static BigDecimal money(BigDecimal value) { return value == null ? BigDecimal.ZERO : value.setScale(2, RoundingMode.HALF_UP); }
    private static String safe(String value) { return value == null ? "" : value.replace("\"", "'"); }
    private static JournalLineRequest line(String code, BigDecimal debit, BigDecimal credit, String description) { return new JournalLineRequest(code, debit, credit, description, null, null); }

    private ReimbursementResponse toResponse(EmployeeExpenseReimbursement c) {
        Employee employee = employeeRepository.findById(c.getEmployeeId()).orElse(null);
        Account account = accountRepository.findById(c.getAccountId()).orElse(null);
        return new ReimbursementResponse(c.getId(), c.getEmployeeId(), employee == null ? null : employee.getFullName(), c.getExpenseId(), c.getExpenseDate(), c.getAccountId(), account == null ? null : account.getCode(), account == null ? null : account.getName(), c.getCategory(), c.getDescription(), c.getAmount(), c.getStatus(), c.getAdvanceApplied(), c.getPayableAmount(), c.getPaidAmount(), c.getReceiptUrl(), c.getNotes(), c.getApprovedBy(), c.getApprovedAt(), c.getRejectedBy(), c.getRejectedAt(), c.getRejectionReason(), c.getPaidThroughId(), c.getPaidAt(), c.getCreatedAt());
    }

    private EmployeeAdvanceResponse toAdvanceResponse(EmployeeExpenseAdvance a) {
        Employee employee = employeeRepository.findById(a.getEmployeeId()).orElse(null);
        return new EmployeeAdvanceResponse(a.getId(), a.getEmployeeId(), employee == null ? null : employee.getFullName(), a.getAdvanceDate(), a.getAmount(), a.getSettledAmount(), a.getAmount().subtract(a.getSettledAmount()), a.getStatus(), a.getPaidThroughId(), a.getJournalEntryId(), a.getNotes());
    }
}




