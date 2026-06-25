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
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Bank-account master (C5). Each bank account mints (or links) its own GL ledger
 * under Bank (1020), enforces a single default, and resolves a GL id for the
 * reconcile picker.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class BankAccountServiceTest {

    @Mock private BankAccountRepository bankAccountRepository;
    @Mock private AccountRepository accountRepository;
    @Mock private AccountService accountService;

    private BankAccountService service;
    private UUID orgId;
    private Map<UUID, BankAccount> saved;

    @BeforeEach
    void setUp() {
        service = new BankAccountService(bankAccountRepository, accountRepository, accountService);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        saved = new HashMap<>();
        lenient().when(bankAccountRepository.save(any(BankAccount.class))).thenAnswer(inv -> {
            BankAccount b = inv.getArgument(0);
            if (b.getId() == null) b.setId(UUID.randomUUID());
            saved.put(b.getId(), b);
            return b;
        });
        lenient().when(bankAccountRepository.findByIdAndOrgIdAndIsDeletedFalse(any(UUID.class), eq(orgId)))
                .thenAnswer(inv -> Optional.ofNullable(saved.get(inv.getArgument(0))));
        // no existing bank accounts / no other defaults by default
        lenient().when(bankAccountRepository.findByOrgIdAndIsDeletedFalseOrderByIsDefaultDescNameAsc(orgId))
                .thenReturn(List.of());
        lenient().when(bankAccountRepository.findOtherDefaults(eq(orgId), any())).thenReturn(List.of());
        lenient().when(bankAccountRepository.existsByOrgIdAndAccountNumberAndIsDeletedFalse(eq(orgId), anyString()))
                .thenReturn(false);

        // CoA starts with just 1010 + 1020 → next bank ledger is 1021
        lenient().when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(account("1010", null), account("1020", null)));
        lenient().when(accountRepository.existsByOrgIdAndCodeAndIsDeletedFalse(eq(orgId), anyString()))
                .thenReturn(false);
        // createAccount echoes the requested code; findByCode then returns a real account
        lenient().when(accountService.createAccount(any(CreateAccountRequest.class)))
                .thenAnswer(inv -> {
                    CreateAccountRequest r = inv.getArgument(0);
                    return accountResponse(r.code());
                });
        lenient().when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(eq(orgId), anyString()))
                .thenAnswer(inv -> Optional.of(account(inv.getArgument(1), UUID.randomUUID())));
        lenient().when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(eq(orgId), any(UUID.class)))
                .thenAnswer(inv -> Optional.of(account("1021", inv.getArgument(1))));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Account account(String code, UUID id) {
        Account a = Account.builder().code(code).name("Acc " + code).type("ASSET").build();
        a.setId(id != null ? id : UUID.randomUUID());
        return a;
    }

    private AccountResponse accountResponse(String code) {
        return new AccountResponse(UUID.randomUUID(), code, "Acc " + code, "ASSET", "CURRENT_ASSET",
                null, null, 3, false, false, false, 0, null, BigDecimal.ZERO, "INR", true);
    }

    private BankAccountRequest req(String name, String glCode, Boolean isDefault) {
        return new BankAccountRequest(name, "HDFC Bank", "5010" + name.hashCode() % 10000,
                "HDFC0001234", "MG Road", "CURRENT", glCode, BigDecimal.ZERO, isDefault, true, null, null);
    }

    @Test
    void create_autoMintsGlLedgerUnder1020_asCode1021() {
        ArgumentCaptor<CreateAccountRequest> cap = ArgumentCaptor.forClass(CreateAccountRequest.class);

        BankAccountResponse resp = service.create(req("HDFC Current", null, null));

        verify(accountService).createAccount(cap.capture());
        assertEquals("1021", cap.getValue().code());
        assertEquals("1020", cap.getValue().parentCode());
        assertEquals("ASSET", cap.getValue().type());
        assertEquals("1021", resp.glAccountCode());
        assertNotNull(resp.glAccountId());
        // first account → default by construction
        assertTrue(resp.isDefault());
    }

    @Test
    void nextBankGlCode_skipsExisting102xLedgers() {
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(account("1010", null), account("1020", null), account("1021", null)));
        ArgumentCaptor<CreateAccountRequest> cap = ArgumentCaptor.forClass(CreateAccountRequest.class);

        service.create(req("SBI Savings", null, null));

        verify(accountService).createAccount(cap.capture());
        assertEquals("1022", cap.getValue().code());
    }

    @Test
    void create_linksExistingGlAccount_doesNotMintOne() {
        BankAccountResponse resp = service.create(req("ICICI OD", "1099", null));

        verify(accountService, never()).createAccount(any());
        assertEquals("1099", resp.glAccountCode());
    }

    @Test
    void create_linkUnknownGlCode_throws() {
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "9999"))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.create(req("Bad", "9999", null)));
        assertEquals("BANK_ACCOUNT_GL_NOT_FOUND", ex.getErrorCode());
    }

    @Test
    void create_secondDefault_clearsThePriorDefault() {
        // an existing bank account already flagged default
        BankAccount existing = BankAccount.builder().orgId(orgId).name("Old").glAccountId(UUID.randomUUID())
                .isDefault(true).build();
        existing.setId(UUID.randomUUID());
        when(bankAccountRepository.findByOrgIdAndIsDeletedFalseOrderByIsDefaultDescNameAsc(orgId))
                .thenReturn(List.of(existing));
        when(bankAccountRepository.findOtherDefaults(eq(orgId), any())).thenReturn(List.of(existing));

        BankAccountResponse resp = service.create(req("New Primary", null, true));

        assertTrue(resp.isDefault());
        assertFalse(existing.isDefault(), "prior default cleared");
        verify(bankAccountRepository).flush();
    }

    @Test
    void create_duplicateAccountNumber_throws() {
        when(bankAccountRepository.existsByOrgIdAndAccountNumberAndIsDeletedFalse(eq(orgId), anyString()))
                .thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.create(req("Dup", null, null)));
        assertEquals("BANK_ACCOUNT_NUMBER_EXISTS", ex.getErrorCode());
    }

    @Test
    void create_invalidType_throws() {
        BankAccountRequest bad = new BankAccountRequest("X", null, "1", null, null,
                "FIXED_DEPOSIT", null, null, null, null, null, null);
        BusinessException ex = assertThrows(BusinessException.class, () -> service.create(bad));
        assertEquals("BANK_ACCOUNT_INVALID_TYPE", ex.getErrorCode());
    }

    @Test
    void resolveGlAccountId_returnsLedger_butThrowsWhenInactive() {
        UUID glId = UUID.randomUUID();
        BankAccount active = BankAccount.builder().orgId(orgId).name("A").glAccountId(glId)
                .isActive(true).build();
        active.setId(UUID.randomUUID());
        saved.put(active.getId(), active);
        assertEquals(glId, service.resolveGlAccountId(active.getId()));

        BankAccount inactive = BankAccount.builder().orgId(orgId).name("B").glAccountId(UUID.randomUUID())
                .isActive(false).build();
        inactive.setId(UUID.randomUUID());
        saved.put(inactive.getId(), inactive);
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.resolveGlAccountId(inactive.getId()));
        assertEquals("BANK_ACCOUNT_INACTIVE", ex.getErrorCode());
    }

    @Test
    void setDefault_clearsOthersAndActivates() {
        BankAccount target = BankAccount.builder().orgId(orgId).name("T").glAccountId(UUID.randomUUID())
                .isDefault(false).isActive(false).build();
        target.setId(UUID.randomUUID());
        saved.put(target.getId(), target);

        // a different account currently holds the default flag
        BankAccount priorDefault = BankAccount.builder().orgId(orgId).name("Old").glAccountId(UUID.randomUUID())
                .isDefault(true).build();
        priorDefault.setId(UUID.randomUUID());
        when(bankAccountRepository.findOtherDefaults(eq(orgId), any())).thenReturn(List.of(priorDefault));

        BankAccountResponse resp = service.setDefault(target.getId());

        assertTrue(resp.isDefault());
        assertTrue(resp.isActive());
        assertFalse(priorDefault.isDefault(), "prior default cleared");
        verify(bankAccountRepository).flush();
    }
}
