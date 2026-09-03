package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.JournalEntryResponse;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.dto.SingleEntryVoucherRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SingleEntryVoucherService {

    private final AccountRepository accountRepository;
    private final JournalService journalService;

    @Transactional
    public JournalEntryResponse postSingleEntryVoucher(SingleEntryVoucherRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Account primaryAccount = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, request.getPrimaryAccountId())
                .orElseThrow(() -> new BusinessException("Primary cash/bank account not found: " + request.getPrimaryAccountId(),
                        "ACCOUNT_NOT_FOUND", HttpStatus.NOT_FOUND));

        if (request.getLines() == null || request.getLines().isEmpty()) {
            throw new BusinessException("At least one line is required for voucher entry",
                    "VOUCHER_EMPTY_LINES", HttpStatus.BAD_REQUEST);
        }

        BigDecimal totalAmount = BigDecimal.ZERO;
        List<JournalLineRequest> journalLines = new ArrayList<>();

        for (SingleEntryVoucherRequest.SingleEntryLine line : request.getLines()) {
            if (line.getAmount() == null || line.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
                throw new BusinessException("Line amount must be positive: " + line.getAmount(),
                        "INVALID_LINE_AMOUNT", HttpStatus.BAD_REQUEST);
            }

            Account lineAccount = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, line.getAccountId())
                    .orElseThrow(() -> new BusinessException("Account not found: " + line.getAccountId(),
                            "ACCOUNT_NOT_FOUND", HttpStatus.NOT_FOUND));

            totalAmount = totalAmount.add(line.getAmount());

            String lineNarration = line.getNarration() != null && !line.getNarration().isBlank()
                    ? line.getNarration()
                    : request.getNarration();

            if (request.getVoucherType() == SingleEntryVoucherRequest.VoucherType.PAYMENT) {
                // Payment: Debit the expense/payable line, Credit the primary bank/cash
                journalLines.add(new JournalLineRequest(
                        lineAccount.getCode(),
                        line.getAmount(),
                        BigDecimal.ZERO,
                        lineNarration,
                        null,
                        null
                ));
            } else if (request.getVoucherType() == SingleEntryVoucherRequest.VoucherType.RECEIPT) {
                // Receipt: Credit the income/receivable line, Debit the primary bank/cash
                journalLines.add(new JournalLineRequest(
                        lineAccount.getCode(),
                        BigDecimal.ZERO,
                        line.getAmount(),
                        lineNarration,
                        null,
                        null
                ));
            } else if (request.getVoucherType() == SingleEntryVoucherRequest.VoucherType.CONTRA) {
                // Contra: Line account (Cash/Bank) is credited
                journalLines.add(new JournalLineRequest(
                        lineAccount.getCode(),
                        BigDecimal.ZERO,
                        line.getAmount(),
                        lineNarration,
                        null,
                        null
                ));
            }
        }

        // Add the primary Cash/Bank leg to balance the journal
        if (request.getVoucherType() == SingleEntryVoucherRequest.VoucherType.PAYMENT) {
            journalLines.add(0, new JournalLineRequest(
                    primaryAccount.getCode(),
                    BigDecimal.ZERO,
                    totalAmount,
                    request.getNarration(),
                    null,
                    null
            ));
        } else if (request.getVoucherType() == SingleEntryVoucherRequest.VoucherType.RECEIPT) {
            journalLines.add(0, new JournalLineRequest(
                    primaryAccount.getCode(),
                    totalAmount,
                    BigDecimal.ZERO,
                    request.getNarration(),
                    null,
                    null
            ));
        } else if (request.getVoucherType() == SingleEntryVoucherRequest.VoucherType.CONTRA) {
            journalLines.add(0, new JournalLineRequest(
                    primaryAccount.getCode(),
                    totalAmount,
                    BigDecimal.ZERO,
                    request.getNarration(),
                    null,
                    null
            ));
        }

        String sourceModule = switch (request.getVoucherType()) {
            case PAYMENT -> "SINGLE_ENTRY_PAYMENT";
            case RECEIPT -> "SINGLE_ENTRY_RECEIPT";
            case CONTRA -> "CONTRA_VOUCHER";
        };

        boolean autoPost = request.getStatus() == null || !request.getStatus().equalsIgnoreCase("DRAFT");

        JournalPostRequest postRequest = new JournalPostRequest(
                request.getDate(),
                request.getNarration() != null && !request.getNarration().isBlank() ? request.getNarration() : "Single-entry " + request.getVoucherType(),
                sourceModule,
                null,
                journalLines,
                autoPost
        );

        JournalEntry postedEntry = journalService.postJournal(postRequest);
        log.info("Single-entry voucher [{}] posted as journal [{}] for amount {}",
                request.getVoucherType(), postedEntry.getEntryNumber(), totalAmount);

        return journalService.toResponse(postedEntry);
    }
}