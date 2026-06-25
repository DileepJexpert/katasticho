package com.katasticho.erp.banking.service;

import com.katasticho.erp.accounting.dto.AccountResponse;
import com.katasticho.erp.accounting.dto.CreateAccountRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.banking.dto.BankAccountRequest;
import com.katasticho.erp.banking.dto.BankAccountResponse;
import com.katasticho.erp.banking.entity.BankAccount;
import com.katasticho.erp.banking.repository.BankAccountRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Bank-account master. Each account links its own GL ledger (a sub-account of
 * Bank 1020) so a multi-bank org keeps its cash movements separated, and the
 * reconciliation / payment flows can pick which bank a transaction belongs to.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BankAccountService {

    private final BankAccountRepository bankAccountRepository;
    private final AccountRepository accountRepository;
    private final AccountService accountService;

    /** Parent GL account every auto-created bank ledger hangs under. */
    private static final String BANK_PARENT_CODE = "1020";
    private static final Set<String> VALID_TYPES =
            Set.of("SAVINGS", "CURRENT", "OD", "CC", "OTHER");

    @Transactional
    public BankAccountResponse create(BankAccountRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        String accountType = normaliseType(request.accountType());

        if (request.accountNumber() != null && !request.accountNumber().isBlank()
                && bankAccountRepository.existsByOrgIdAndAccountNumberAndIsDeletedFalse(
                        orgId, request.accountNumber().trim())) {
            throw new BusinessException(
                    "A bank account with number " + request.accountNumber() + " already exists",
                    "BANK_ACCOUNT_NUMBER_EXISTS", HttpStatus.CONFLICT);
        }

        // Resolve the GL ledger: link an existing account, or mint a fresh
        // sub-account under Bank (1020).
        Account gl = resolveOrCreateGlAccount(orgId, request);

        // First bank account becomes the default automatically.
        boolean isFirst = bankAccountRepository
                .findByOrgIdAndIsDeletedFalseOrderByIsDefaultDescNameAsc(orgId).isEmpty();
        boolean wantsDefault = Boolean.TRUE.equals(request.isDefault()) || isFirst;
        if (wantsDefault) {
            clearOtherDefaults(orgId, null);
        }

        BankAccount account = BankAccount.builder()
                .orgId(orgId)
                .branchId(request.branchId())
                .name(request.name().trim())
                .bankName(trimToNull(request.bankName()))
                .accountNumber(trimToNull(request.accountNumber()))
                .ifsc(trimToNull(request.ifsc()))
                .branch(trimToNull(request.branch()))
                .accountType(accountType)
                .glAccountId(gl.getId())
                .openingBalance(request.openingBalance() != null ? request.openingBalance() : BigDecimal.ZERO)
                .isDefault(wantsDefault)
                .isActive(request.isActive() == null || request.isActive())
                .notes(trimToNull(request.notes()))
                .createdBy(userId)
                .build();

        account = bankAccountRepository.save(account);
        account.setGlAccountCode(gl.getCode());
        log.info("Bank account {} created (GL {}) for org {}", account.getName(), gl.getCode(), orgId);
        return BankAccountResponse.from(account);
    }

    @Transactional
    public BankAccountResponse update(UUID id, BankAccountRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BankAccount account = require(id, orgId);

        if (request.accountNumber() != null && !request.accountNumber().isBlank()
                && !request.accountNumber().trim().equals(account.getAccountNumber())
                && bankAccountRepository.existsByOrgIdAndAccountNumberAndIsDeletedFalse(
                        orgId, request.accountNumber().trim())) {
            throw new BusinessException(
                    "A bank account with number " + request.accountNumber() + " already exists",
                    "BANK_ACCOUNT_NUMBER_EXISTS", HttpStatus.CONFLICT);
        }

        account.setName(request.name().trim());
        account.setBankName(trimToNull(request.bankName()));
        account.setAccountNumber(trimToNull(request.accountNumber()));
        account.setIfsc(trimToNull(request.ifsc()));
        account.setBranch(trimToNull(request.branch()));
        account.setAccountType(normaliseType(request.accountType()));
        account.setNotes(trimToNull(request.notes()));
        if (request.openingBalance() != null) account.setOpeningBalance(request.openingBalance());
        if (request.isActive() != null) account.setActive(request.isActive());

        if (Boolean.TRUE.equals(request.isDefault()) && !account.isDefault()) {
            clearOtherDefaults(orgId, account.getId());
            account.setDefault(true);
        }

        account = bankAccountRepository.save(account);
        return withGlCode(account);
    }

    @Transactional
    public BankAccountResponse setDefault(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BankAccount account = require(id, orgId);
        clearOtherDefaults(orgId, account.getId());
        account.setDefault(true);
        account.setActive(true);
        return withGlCode(bankAccountRepository.save(account));
    }

    @Transactional
    public void delete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BankAccount account = require(id, orgId);
        account.setDeleted(true);
        account.setDefault(false);
        bankAccountRepository.save(account);
    }

    @Transactional(readOnly = true)
    public List<BankAccountResponse> list(boolean activeOnly) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<BankAccount> rows = activeOnly
                ? bankAccountRepository.findByOrgIdAndIsActiveTrueAndIsDeletedFalseOrderByIsDefaultDescNameAsc(orgId)
                : bankAccountRepository.findByOrgIdAndIsDeletedFalseOrderByIsDefaultDescNameAsc(orgId);
        return rows.stream().map(this::withGlCode).toList();
    }

    @Transactional(readOnly = true)
    public BankAccountResponse get(UUID id) {
        return withGlCode(require(id, TenantContext.getCurrentOrgId()));
    }

    /**
     * GL account id a bank account posts to — used by the reconciliation accept
     * flow so a payment lands in the right ledger. Throws if the account is
     * missing/inactive so a stale picker can't silently post to nowhere.
     */
    @Transactional(readOnly = true)
    public UUID resolveGlAccountId(UUID bankAccountId) {
        BankAccount account = require(bankAccountId, TenantContext.getCurrentOrgId());
        if (!account.isActive()) {
            throw new BusinessException("Bank account " + account.getName() + " is inactive",
                    "BANK_ACCOUNT_INACTIVE", HttpStatus.BAD_REQUEST);
        }
        return account.getGlAccountId();
    }

    // ── Helpers ─────────────────────────────────────────────────

    private Account resolveOrCreateGlAccount(UUID orgId, BankAccountRequest request) {
        if (request.glAccountCode() != null && !request.glAccountCode().isBlank()) {
            return accountRepository
                    .findByOrgIdAndCodeAndIsDeletedFalse(orgId, request.glAccountCode().trim())
                    .orElseThrow(() -> new BusinessException(
                            "GL account not found: " + request.glAccountCode(),
                            "BANK_ACCOUNT_GL_NOT_FOUND", HttpStatus.BAD_REQUEST));
        }
        // Mint a dedicated ledger under Bank (1020).
        String code = nextBankGlCode(orgId);
        AccountResponse created = accountService.createAccount(new CreateAccountRequest(
                code,
                request.name().trim(),
                "ASSET",
                "CURRENT_ASSET",
                BANK_PARENT_CODE,
                "Bank account ledger",
                request.openingBalance() != null ? request.openingBalance() : BigDecimal.ZERO));
        return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, created.code())
                .orElseThrow(() -> new BusinessException(
                        "Failed to create bank GL account", "BANK_ACCOUNT_GL_CREATE_FAILED",
                        HttpStatus.INTERNAL_SERVER_ERROR));
    }

    /** Lowest free numeric code in the 102x bank family, floor 1021. */
    private String nextBankGlCode(UUID orgId) {
        int max = 1020;
        for (Account a : accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)) {
            String c = a.getCode();
            if (c != null && c.matches("102\\d+")) {
                try {
                    max = Math.max(max, Integer.parseInt(c));
                } catch (NumberFormatException ignored) {
                    // non-numeric in the family — skip
                }
            }
        }
        int next = max + 1;
        while (accountRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, String.valueOf(next))) {
            next++;
        }
        return String.valueOf(next);
    }

    private void clearOtherDefaults(UUID orgId, UUID excludeId) {
        List<BankAccount> others = bankAccountRepository.findOtherDefaults(orgId, excludeId);
        if (others.isEmpty()) return;
        others.forEach(b -> b.setDefault(false));
        bankAccountRepository.saveAll(others);
        // Flush so the partial-unique "one default" index frees its slot before
        // the new default row is written in the same transaction.
        bankAccountRepository.flush();
    }

    private BankAccount require(UUID id, UUID orgId) {
        return bankAccountRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("BankAccount", id));
    }

    private BankAccountResponse withGlCode(BankAccount account) {
        accountRepository.findByOrgIdAndIdAndIsDeletedFalse(account.getOrgId(), account.getGlAccountId())
                .ifPresent(a -> account.setGlAccountCode(a.getCode()));
        return BankAccountResponse.from(account);
    }

    private String normaliseType(String type) {
        if (type == null || type.isBlank()) return "CURRENT";
        String t = type.trim().toUpperCase();
        if (!VALID_TYPES.contains(t)) {
            throw new BusinessException("Invalid bank account type: " + type,
                    "BANK_ACCOUNT_INVALID_TYPE", HttpStatus.BAD_REQUEST);
        }
        return t;
    }

    private String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }
}
