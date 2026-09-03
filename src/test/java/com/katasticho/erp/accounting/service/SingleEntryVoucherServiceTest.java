package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.JournalEntryResponse;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.dto.SingleEntryVoucherRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SingleEntryVoucherServiceTest {

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private JournalService journalService;

    @InjectMocks
    private SingleEntryVoucherService singleEntryVoucherService;

    private UUID orgId;
    private UUID bankAccountId;
    private UUID rentAccountId;
    private UUID electricityAccountId;
    private Account bankAccount;
    private Account rentAccount;
    private Account electricityAccount;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);

        bankAccountId = UUID.randomUUID();
        rentAccountId = UUID.randomUUID();
        electricityAccountId = UUID.randomUUID();

        bankAccount = Account.builder()
                .code("1020")
                .name("HDFC Bank")
                .type("ASSET")
                .build();
        bankAccount.setId(bankAccountId);
        bankAccount.setOrgId(orgId);

        rentAccount = Account.builder()
                .code("5010")
                .name("Rent Expense")
                .type("EXPENSE")
                .build();
        rentAccount.setId(rentAccountId);
        rentAccount.setOrgId(orgId);

        electricityAccount = Account.builder()
                .code("5020")
                .name("Electricity Expense")
                .type("EXPENSE")
                .build();
        electricityAccount.setId(electricityAccountId);
        electricityAccount.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void postPaymentVoucher_success() {
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, bankAccountId)).thenReturn(Optional.of(bankAccount));
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, rentAccountId)).thenReturn(Optional.of(rentAccount));
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, electricityAccountId)).thenReturn(Optional.of(electricityAccount));

        JournalEntry mockEntry = JournalEntry.builder()
                .orgId(orgId)
                .entryNumber("JE-2026-0001")
                .build();
        mockEntry.setId(UUID.randomUUID());

        JournalEntryResponse mockResponse = new JournalEntryResponse(
                mockEntry.getId(),
                "JE-2026-0001",
                LocalDate.now(),
                Instant.now(),
                "Office Monthly Expenses",
                "SINGLE_ENTRY_PAYMENT",
                null,
                "POSTED",
                false,
                false,
                null,
                2026,
                8,
                new BigDecimal("15000.00"),
                List.of()
        );

        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(mockEntry);
        when(journalService.toResponse(mockEntry)).thenReturn(mockResponse);

        SingleEntryVoucherRequest request = SingleEntryVoucherRequest.builder()
                .voucherType(SingleEntryVoucherRequest.VoucherType.PAYMENT)
                .primaryAccountId(bankAccountId)
                .date(LocalDate.now())
                .referenceNumber("CHQ-98124")
                .narration("Office Monthly Expenses")
                .lines(List.of(
                        SingleEntryVoucherRequest.SingleEntryLine.builder().accountId(rentAccountId).amount(new BigDecimal("10000.00")).narration("Office Rent").build(),
                        SingleEntryVoucherRequest.SingleEntryLine.builder().accountId(electricityAccountId).amount(new BigDecimal("5000.00")).narration("Electricity Bill").build()
                ))
                .build();

        JournalEntryResponse response = singleEntryVoucherService.postSingleEntryVoucher(request);

        assertThat(response).isNotNull();
        assertThat(response.entryNumber()).isEqualTo("JE-2026-0001");

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());

        JournalPostRequest captured = captor.getValue();
        assertThat(captured.sourceModule()).isEqualTo("SINGLE_ENTRY_PAYMENT");
        assertThat(captured.lines()).hasSize(3);
        // First line is primary Bank Credit
        assertThat(captured.lines().get(0).accountCode()).isEqualTo("1020");
        assertThat(captured.lines().get(0).credit()).isEqualByComparingTo("15000.00");
        assertThat(captured.lines().get(0).debit()).isEqualByComparingTo("0.00");
    }

    @Test
    void postReceiptVoucher_success() {
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, bankAccountId)).thenReturn(Optional.of(bankAccount));
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, rentAccountId)).thenReturn(Optional.of(rentAccount));

        JournalEntry mockEntry = JournalEntry.builder()
                .orgId(orgId)
                .entryNumber("JE-2026-0002")
                .build();
        mockEntry.setId(UUID.randomUUID());

        JournalEntryResponse mockResponse = new JournalEntryResponse(
                mockEntry.getId(),
                "JE-2026-0002",
                LocalDate.now(),
                Instant.now(),
                "Rental Income Received",
                "SINGLE_ENTRY_RECEIPT",
                null,
                "POSTED",
                false,
                false,
                null,
                2026,
                8,
                new BigDecimal("25000.00"),
                List.of()
        );

        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(mockEntry);
        when(journalService.toResponse(mockEntry)).thenReturn(mockResponse);

        SingleEntryVoucherRequest request = SingleEntryVoucherRequest.builder()
                .voucherType(SingleEntryVoucherRequest.VoucherType.RECEIPT)
                .primaryAccountId(bankAccountId)
                .date(LocalDate.now())
                .narration("Rental Income Received")
                .lines(List.of(
                        SingleEntryVoucherRequest.SingleEntryLine.builder().accountId(rentAccountId).amount(new BigDecimal("25000.00")).build()
                ))
                .build();

        JournalEntryResponse response = singleEntryVoucherService.postSingleEntryVoucher(request);

        assertThat(response).isNotNull();
        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());

        JournalPostRequest captured = captor.getValue();
        assertThat(captured.sourceModule()).isEqualTo("SINGLE_ENTRY_RECEIPT");
        // First line is primary Bank Debit
        assertThat(captured.lines().get(0).accountCode()).isEqualTo("1020");
        assertThat(captured.lines().get(0).debit()).isEqualByComparingTo("25000.00");
    }

    @Test
    void postVoucher_invalidAccount_throwsException() {
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, bankAccountId)).thenReturn(Optional.empty());

        SingleEntryVoucherRequest request = SingleEntryVoucherRequest.builder()
                .voucherType(SingleEntryVoucherRequest.VoucherType.PAYMENT)
                .primaryAccountId(bankAccountId)
                .date(LocalDate.now())
                .lines(List.of(SingleEntryVoucherRequest.SingleEntryLine.builder().accountId(rentAccountId).amount(new BigDecimal("500.00")).build()))
                .build();

        assertThatThrownBy(() -> singleEntryVoucherService.postSingleEntryVoucher(request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Primary cash/bank account not found");
    }

    @Test
    void postVoucher_emptyLines_throwsException() {
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, bankAccountId)).thenReturn(Optional.of(bankAccount));

        SingleEntryVoucherRequest request = SingleEntryVoucherRequest.builder()
                .voucherType(SingleEntryVoucherRequest.VoucherType.PAYMENT)
                .primaryAccountId(bankAccountId)
                .date(LocalDate.now())
                .lines(List.of())
                .build();

        assertThatThrownBy(() -> singleEntryVoucherService.postSingleEntryVoucher(request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("At least one line is required");
    }
}