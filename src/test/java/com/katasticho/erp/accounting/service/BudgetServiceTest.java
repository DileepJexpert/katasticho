package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.BudgetLine;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.BudgetLineRepository;
import com.katasticho.erp.accounting.service.BudgetService.BudgetLineDto;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class BudgetServiceTest {

    private final BudgetLineRepository budgetLineRepository = mock(BudgetLineRepository.class);
    private final AccountRepository accountRepository = mock(AccountRepository.class);

    private final BudgetService service = new BudgetService(budgetLineRepository, accountRepository);

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(eq(orgId), any()))
                .thenAnswer(inv -> {
                    Account a = Account.builder()
                            .code(inv.getArgument(1)).name("Acct").type("EXPENSE").build();
                    return Optional.of(a);
                });
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)).thenReturn(List.of());
        when(budgetLineRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void saveUpsertsExistingAndSoftDeletesRemoved() {
        BudgetLine rent = BudgetLine.builder()
                .fiscalYear(2026).accountCode("5200").annualAmount(new BigDecimal("100000")).build();
        rent.setOrgId(orgId);
        BudgetLine removed = BudgetLine.builder()
                .fiscalYear(2026).accountCode("5210").annualAmount(new BigDecimal("50000")).build();
        removed.setOrgId(orgId);
        when(budgetLineRepository.findByOrgIdAndFiscalYearAndIsDeletedFalseOrderByAccountCode(orgId, 2026))
                .thenReturn(List.of(rent, removed)).thenReturn(List.of());

        service.save(2026, List.of(
                new BudgetLineDto("5200", null, new BigDecimal("120000"), null),   // updated
                new BudgetLineDto("5300", null, new BigDecimal("30000"), null)));  // new

        // Updated in place.
        assertThat(rent.getAnnualAmount()).isEqualByComparingTo("120000");
        assertThat(rent.isDeleted()).isFalse();
        // Removed line soft-deleted.
        assertThat(removed.isDeleted()).isTrue();
        // New line saved with the right code.
        ArgumentCaptor<BudgetLine> cap = ArgumentCaptor.forClass(BudgetLine.class);
        verify(budgetLineRepository, times(3)).save(cap.capture());
        assertThat(cap.getAllValues()).anyMatch(b ->
                "5300".equals(b.getAccountCode())
                        && b.getAnnualAmount().compareTo(new BigDecimal("30000")) == 0);
    }

    @Test
    void saveRejectsUnknownAccountCode() {
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "9999"))
                .thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.save(2026, List.of(
                new BudgetLineDto("9999", null, BigDecimal.TEN, null))))
                .hasMessageContaining("No account with code 9999");
    }
}
