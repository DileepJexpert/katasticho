package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.JournalEntryResponse;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.EntryNumberSequence;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.entity.JournalLine;
import com.katasticho.erp.accounting.repository.*;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
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
 * THE SINGLE POSTING GATE.
 * ALL financial writes in the entire ERP go through postJournal().
 * NO module (AR, AP, Payroll, Inventory) writes to journal_entry or journal_line directly.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class JournalService {

    private final JournalEntryRepository journalEntryRepository;
    private final JournalLineRepository journalLineRepository;
    private final AccountRepository accountRepository;
    private final EntryNumberSequenceRepository sequenceRepository;
    private final OrganisationRepository organisationRepository;
    private final CurrencyService currencyService;
    private final AuditService auditService;

    /**
     * THE MOST IMPORTANT METHOD IN THE ENTIRE CODEBASE.
     * Follows the 13 steps from the architecture document.
     */
    @Transactional
    public JournalEntry postJournal(JournalPostRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        // Step 1: Validate org exists
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        // Step 2: Validate all accounts exist and belong to this org
        List<Account> resolvedAccounts = new ArrayList<>();
        for (JournalLineRequest line : request.lines()) {
            Account account = accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, line.accountCode())
                    .orElseThrow(() -> new BusinessException(
                            "Account not found: " + line.accountCode(),
                            "ACCT_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
            resolvedAccounts.add(account);
        }

        // Step 3: Validate double-entry balance in TRANSACTION currency
        BigDecimal totalDebit = request.lines().stream()
                .map(JournalLineRequest::debit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalCredit = request.lines().stream()
                .map(JournalLineRequest::credit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (totalDebit.compareTo(totalCredit) != 0) {
            throw new BusinessException(
                    "Journal does not balance. Debit: " + totalDebit + ", Credit: " + totalCredit,
                    "ACCT_JOURNAL_IMBALANCE", HttpStatus.BAD_REQUEST);
        }

        if (totalDebit.compareTo(BigDecimal.ZERO) == 0) {
            throw new BusinessException(
                    "Journal has zero amounts",
                    "ACCT_JOURNAL_ZERO", HttpStatus.BAD_REQUEST);
        }

        // Step 4 & 5: Convert to base currency (rate=1.0 in v1)
        // In v3, this will fetch real exchange rates

        // Step 6: Determine fiscal period from effective_date + org.fiscalYearStart
        int periodYear = computeFiscalYear(request.effectiveDate(), org.getFiscalYearStart());
        int periodMonth = request.effectiveDate().getMonthValue();

        // Step 7: Generate entry number
        String entryNumber = generateEntryNumber(orgId, periodYear);

        // Step 8: Create JournalEntry
        JournalEntry entry = JournalEntry.builder()
                .orgId(orgId)
                .entryNumber(entryNumber)
                .effectiveDate(request.effectiveDate())
                .description(request.description())
                .sourceModule(request.sourceModule())
                .sourceId(request.sourceId())
                .status("DRAFT")
                .periodYear(periodYear)
                .periodMonth(periodMonth)
                .createdBy(userId)
                .build();

        // Step 9: Create JournalLine entities
        for (int i = 0; i < request.lines().size(); i++) {
            JournalLineRequest lineReq = request.lines().get(i);
            Account account = resolvedAccounts.get(i);

            BigDecimal rate = currencyService.getRate("INR", org.getBaseCurrency(), request.effectiveDate());

            JournalLine line = JournalLine.builder()
                    .accountId(account.getId())
                    .description(lineReq.description())
                    .currency("INR")
                    .debit(lineReq.debit().setScale(2, RoundingMode.HALF_UP))
                    .credit(lineReq.credit().setScale(2, RoundingMode.HALF_UP))
                    .exchangeRate(rate)
                    .baseDebit(lineReq.debit().multiply(rate).setScale(2, RoundingMode.HALF_UP))
                    .baseCredit(lineReq.credit().multiply(rate).setScale(2, RoundingMode.HALF_UP))
                    .taxComponentCode(lineReq.taxComponentCode())
                    .costCentre(lineReq.costCentre())
                    .build();

            entry.addLine(line);
        }

        // Step 10: Persist
        entry = journalEntryRepository.save(entry);

        // Auto-post if requested and no approval needed
        if (request.autoPost()) {
            entry.setStatus("POSTED");
            entry = journalEntryRepository.save(entry);
        }

        // Step 12: Audit log
        auditService.log("JOURNAL_ENTRY", entry.getId(), "CREATE", null,
                "{\"entryNumber\":\"" + entry.getEntryNumber() + "\",\"status\":\"" + entry.getStatus() + "\"}");

        log.info("Journal {} created: {} lines, status={}", entry.getEntryNumber(), entry.getLines().size(), entry.getStatus());
        return entry;
    }

    /**
     * Post a DRAFT journal entry (DRAFT -> POSTED).
     * DB trigger enforces balance check at this transition.
     */
    @Transactional
    public JournalEntry postEntry(UUID entryId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        JournalEntry entry = journalEntryRepository.findByIdAndOrgId(entryId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JournalEntry", entryId));

        if (!"DRAFT".equals(entry.getStatus())) {
            throw new BusinessException("Only DRAFT entries can be posted", "ACCT_ENTRY_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        entry.setStatus("POSTED");
        entry = journalEntryRepository.save(entry);

        auditService.log("JOURNAL_ENTRY", entry.getId(), "UPDATE", "{\"status\":\"DRAFT\"}", "{\"status\":\"POSTED\"}");
        log.info("Journal {} posted", entry.getEntryNumber());
        return entry;
    }

    /**
     * Create a REVERSAL entry for a POSTED entry.
     * Original entry marked is_reversed=TRUE. New entry has swapped debits/credits.
     */
    @Transactional
    public JournalEntry reverseEntry(UUID entryId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        JournalEntry original = journalEntryRepository.findByIdAndOrgId(entryId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JournalEntry", entryId));

        if (!"POSTED".equals(original.getStatus())) {
            throw new BusinessException("Only POSTED entries can be reversed", "ACCT_ENTRY_NOT_POSTED", HttpStatus.BAD_REQUEST);
        }
        if (original.isReversed()) {
            throw new BusinessException("Entry already reversed", "ACCT_ENTRY_ALREADY_REVERSED", HttpStatus.CONFLICT);
        }

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        LocalDate today = LocalDate.now();
        int periodYear = computeFiscalYear(today, org.getFiscalYearStart());
        String entryNumber = generateEntryNumber(orgId, periodYear);

        // Create reversal entry with swapped debits/credits
        JournalEntry reversal = JournalEntry.builder()
                .orgId(orgId)
                .entryNumber(entryNumber)
                .effectiveDate(today)
                .description("Reversal of " + original.getEntryNumber() + ": " + original.getDescription())
                .sourceModule(original.getSourceModule())
                .sourceId(original.getSourceId())
                .status("POSTED")
                .reversalOfId(original.getId())
                .reversal(true)
                .periodYear(periodYear)
                .periodMonth(today.getMonthValue())
                .createdBy(userId)
                .build();

        // Swap debit and credit for each line
        for (JournalLine origLine : original.getLines()) {
            JournalLine reversalLine = JournalLine.builder()
                    .accountId(origLine.getAccountId())
                    .description("Reversal: " + (origLine.getDescription() != null ? origLine.getDescription() : ""))
                    .currency(origLine.getCurrency())
                    .debit(origLine.getCredit())       // SWAP
                    .credit(origLine.getDebit())       // SWAP
                    .exchangeRate(origLine.getExchangeRate())
                    .baseDebit(origLine.getBaseCredit())   // SWAP
                    .baseCredit(origLine.getBaseDebit())   // SWAP
                    .taxComponentCode(origLine.getTaxComponentCode())
                    .costCentre(origLine.getCostCentre())
                    .build();
            reversal.addLine(reversalLine);
        }

        reversal = journalEntryRepository.save(reversal);

        // Mark original as reversed (the ONLY update allowed on a POSTED entry)
        original.setReversed(true);
        journalEntryRepository.save(original);

        auditService.log("JOURNAL_ENTRY", reversal.getId(), "CREATE", null,
                "{\"action\":\"reversal\",\"reversalOf\":\"" + original.getEntryNumber() + "\"}");

        log.info("Journal {} reversed by {}", original.getEntryNumber(), reversal.getEntryNumber());
        return reversal;
    }

    public JournalEntryResponse toResponse(JournalEntry entry) {
        List<JournalEntryResponse.LineResponse> lineResponses = entry.getLines().stream()
                .map(line -> {
                    Account account = accountRepository.findById(line.getAccountId()).orElse(null);
                    return new JournalEntryResponse.LineResponse(
                            line.getId(),
                            line.getAccountId(),
                            account != null ? account.getCode() : null,
                            account != null ? account.getName() : null,
                            line.getDescription(),
                            line.getDebit(), line.getCredit(),
                            line.getCurrency(), line.getExchangeRate(),
                            line.getBaseDebit(), line.getBaseCredit(),
                            line.getTaxComponentCode());
                }).toList();

        BigDecimal totalDebit = entry.getLines().stream()
                .map(JournalLine::getDebit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new JournalEntryResponse(
                entry.getId(), entry.getEntryNumber(), entry.getEffectiveDate(),
                entry.getCreatedAt(), entry.getDescription(), entry.getSourceModule(),
                entry.getSourceId(), entry.getStatus(), entry.isReversal(), entry.isReversed(),
                entry.getReversalOfId(), entry.getPeriodYear(), entry.getPeriodMonth(),
                totalDebit, lineResponses);
    }

    public Page<JournalEntry> listEntries(UUID orgId, Pageable pageable) {
        return journalEntryRepository.findByOrgIdOrderByEffectiveDateDesc(orgId, pageable);
    }

    public Page<JournalEntry> listEntries(UUID orgId, String sourceModule, LocalDate dateFrom, LocalDate dateTo,
                                           String search, Pageable pageable) {
        return journalEntryRepository.findFiltered(orgId, sourceModule, dateFrom, dateTo, search, pageable);
    }

    @Transactional
    public void deleteEntry(UUID entryId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        JournalEntry entry = journalEntryRepository.findByIdAndOrgId(entryId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JournalEntry", entryId));

        if (!"MANUAL".equals(entry.getSourceModule())) {
            throw new BusinessException("Only manual journal entries can be deleted",
                    "ACCT_CANNOT_DELETE_AUTO", HttpStatus.BAD_REQUEST);
        }
        if ("POSTED".equals(entry.getStatus())) {
            throw new BusinessException("Posted entries cannot be deleted. Create a reversal instead.",
                    "ACCT_CANNOT_DELETE_POSTED", HttpStatus.BAD_REQUEST);
        }

        journalEntryRepository.delete(entry);
        auditService.log("JOURNAL_ENTRY", entryId, "DELETE", null,
                "{\"entryNumber\":\"" + entry.getEntryNumber() + "\"}");
        log.info("Manual journal {} deleted", entry.getEntryNumber());
    }

    public JournalEntry getEntry(UUID entryId, UUID orgId) {
        return journalEntryRepository.findByIdAndOrgId(entryId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JournalEntry", entryId));
    }

    /**
     * Compute account balance from journal lines (Event Sourcing).
     * For LIABILITY/EQUITY/REVENUE: flip sign (credit-normal accounts).
     */
    public BigDecimal getAccountBalance(UUID accountId, UUID orgId, LocalDate asOfDate) {
        Account account = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId)
                .orElseThrow(() -> BusinessException.notFound("Account", accountId));

        BigDecimal rawBalance = journalLineRepository.computeRawBalance(accountId, orgId, asOfDate);
        if (rawBalance == null) rawBalance = BigDecimal.ZERO;

        // Flip sign for credit-normal accounts
        if ("LIABILITY".equals(account.getType()) || "EQUITY".equals(account.getType())
                || "REVENUE".equals(account.getType())) {
            rawBalance = rawBalance.negate();
        }

        return rawBalance;
    }

    private String generateEntryNumber(UUID orgId, int year) {
        var seqOpt = sequenceRepository.findByOrgIdAndYear(orgId, year);
        long nextVal;

        if (seqOpt.isPresent()) {
            nextVal = seqOpt.get().getNextValue();
            sequenceRepository.incrementAndGet(orgId, year);
        } else {
            var seq = EntryNumberSequence.builder()
                    .id(new EntryNumberSequence.EntryNumberSequenceId(orgId, year))
                    .nextValue(2L)
                    .build();
            sequenceRepository.save(seq);
            nextVal = 1L;
        }

        return String.format("JE-%d-%06d", year, nextVal);
    }

    private int computeFiscalYear(LocalDate date, int fiscalYearStartMonth) {
        if (date.getMonthValue() >= fiscalYearStartMonth) {
            return date.getYear();
        }
        return date.getYear() - 1;
    }
}
