package com.katasticho.erp.banking.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.ap.dto.VendorPaymentRequest;
import com.katasticho.erp.ap.dto.VendorPaymentResponse;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.service.VendorPaymentService;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.banking.dto.BankTransactionImportResponse;
import com.katasticho.erp.banking.dto.BankTransactionResponse;
import com.katasticho.erp.banking.dto.ImportBankTransactionsRequest;
import com.katasticho.erp.banking.dto.PaymentMatchResponse;
import com.katasticho.erp.banking.entity.BankRule;
import com.katasticho.erp.banking.entity.BankTransaction;
import com.katasticho.erp.banking.entity.PaymentMatch;
import com.katasticho.erp.banking.repository.BankTransactionRepository;
import com.katasticho.erp.banking.repository.PaymentMatchRepository;
import com.katasticho.erp.banking.service.BankStatementParser.ParsedBankRow;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class BankReconciliationService {

    private static final Pattern UPI_VPA_PATTERN =
            Pattern.compile("(^|[^A-Za-z0-9._-])([A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9._-]{1,64})(?=$|[^A-Za-z0-9._-])");
    private static final Set<String> COMMON_EMAIL_DOMAINS = Set.of(
            "gmail", "googlemail", "yahoo", "outlook", "hotmail", "live", "icloud", "proton", "protonmail"
    );
    private static final int MAX_INVOICES_TO_SCORE = 200;

    private final BankTransactionRepository bankTransactionRepository;
    private final PaymentMatchRepository paymentMatchRepository;
    private final InvoiceRepository invoiceRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final ContactRepository contactRepository;
    private final PaymentService paymentService;
    private final VendorPaymentService vendorPaymentService;
    private final DefaultAccountService defaultAccountService;
    private final BankStatementParser statementParser;
    private final BankAccountService bankAccountService;
    private final BankRuleService bankRuleService;
    private final JournalService journalService;
    private final AccountRepository accountRepository;
    private final FiscalPeriodRepository fiscalPeriodRepository;
    private final OrganisationRepository organisationRepository;

    @Transactional
    public BankTransactionImportResponse importCsv(ImportBankTransactionsRequest request) {
        return importRows(statementParser.parseText(request.csvText()));
    }

    /** Statement file upload (.csv/.xlsx) — header auto-detected, AI fallback for odd formats. */
    @Transactional
    public BankTransactionImportResponse importFile(String filename, byte[] bytes) {
        return importRows(statementParser.parseFile(filename, bytes));
    }

    private BankTransactionImportResponse importRows(List<ParsedBankRow> rows) {
        UUID orgId = requireOrgId();
        int skipped = 0;
        List<BankTransactionResponse> imported = new ArrayList<>();

        for (ParsedBankRow row : rows) {
            // Dedupe on the FULL identity (ref + date + amount + direction), not
            // ref + direction alone — recurring same-reference rows (NACH/EMI
            // mandates repeat the UMRN; split charge+GST rows share a ref on one
            // day) were silently dropped as "duplicates". Amount is scaled to
            // match the persisted value so a true re-import still dedupes.
            if (row.reference() != null
                    && !row.reference().isBlank()
                    && bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(
                            orgId, row.reference(), row.direction(), row.date(),
                            row.amount().setScale(2, RoundingMode.HALF_UP))) {
                skipped++;
                continue;
            }

            BankTransaction transaction = bankTransactionRepository.save(
                    BankTransaction.builder()
                            .orgId(orgId)
                            .transactionDate(row.date())
                            .amount(row.amount().setScale(2, RoundingMode.HALF_UP))
                            .direction(row.direction())
                            .narration(row.narration())
                            .utr(row.reference())
                            .payerName(row.payerName())
                            .payerVpa(row.payerVpa())
                            .status("UNMATCHED")
                            .build()
            );

            // User-defined bank rules take precedence: a matched transaction is a
            // categorisation (charges/interest/utility/etc.), not a document payment,
            // so it skips invoice/bill scoring entirely.
            Optional<BankRule> rule = bankRuleService.firstMatch(orgId, transaction);
            if (rule.isPresent()) {
                PaymentMatch accountMatch = paymentMatchRepository.save(
                        buildAccountMatch(orgId, transaction, rule.get()));
                boolean hasReference = row.reference() != null && !row.reference().isBlank();
                boolean autoApplied = false;
                // Auto-post ONLY when the rule opts in AND the row carries a reference:
                // a reference-less row bypasses import dedup (existsByOrgIdAndUtrAndDirection),
                // so auto-posting it would re-book the journal on every re-import. Reference-less
                // matches fall back to a suggestion so a human catches re-import duplicates.
                if (rule.get().isAutoApply() && hasReference) {
                    try {
                        imported.add(acceptMatch(accountMatch.getId())); // posts journal + marks MATCHED
                        autoApplied = true;
                    } catch (RuntimeException e) {
                        // An un-postable auto-apply (e.g. the target GL was deleted) must not
                        // sink the whole statement import — leave it as a suggestion.
                        log.warn("Auto-apply failed for bank rule on transaction {}: {} — left as a suggestion",
                                transaction.getId(), e.getMessage());
                    }
                }
                if (!autoApplied) {
                    transaction.setStatus("SUGGESTED");
                    transaction = bankTransactionRepository.save(transaction);
                    imported.add(toResponse(transaction, List.of(accountMatch)));
                }
                continue;
            }

            List<PaymentMatch> matches = buildMatches(orgId, transaction);
            if (!matches.isEmpty()) {
                paymentMatchRepository.saveAll(matches);
                transaction.setStatus("SUGGESTED");
                transaction = bankTransactionRepository.save(transaction);
            }
            imported.add(toResponse(transaction, matches));
        }

        return new BankTransactionImportResponse(imported.size(), skipped, imported);
    }

    /** Reconciliation health: counts per status + matched/unmatched value per side. */
    @Transactional(readOnly = true)
    public Map<String, Object> summary() {
        UUID orgId = requireOrgId();
        Map<String, Object> result = new LinkedHashMap<>();
        for (String status : List.of("UNMATCHED", "SUGGESTED", "MATCHED", "IGNORED")) {
            result.put(status.toLowerCase(Locale.ROOT),
                    bankTransactionRepository.countByOrgIdAndStatus(orgId, status));
        }
        result.put("creditUnmatchedTotal", bankTransactionRepository
                .sumAmountByOrgIdAndDirectionAndStatuses(orgId, "CREDIT", List.of("UNMATCHED", "SUGGESTED")));
        result.put("debitUnmatchedTotal", bankTransactionRepository
                .sumAmountByOrgIdAndDirectionAndStatuses(orgId, "DEBIT", List.of("UNMATCHED", "SUGGESTED")));
        return result;
    }

    @Transactional(readOnly = true)
    public PagedResponse<BankTransactionResponse> list(String status, Pageable pageable) {
        UUID orgId = requireOrgId();
        var page = (status == null || status.isBlank() || "ALL".equalsIgnoreCase(status))
                ? bankTransactionRepository.findByOrgIdOrderByTransactionDateDescCreatedAtDesc(orgId, pageable)
                : bankTransactionRepository.findByOrgIdAndStatusOrderByTransactionDateDescCreatedAtDesc(
                        orgId, status.trim().toUpperCase(), pageable);

        List<UUID> transactionIds = page.getContent().stream().map(BankTransaction::getId).toList();
        Map<UUID, List<PaymentMatch>> matchMap = transactionIds.isEmpty()
                ? Map.of()
                : paymentMatchRepository.findByOrgIdAndBankTransactionIdInOrderByConfidenceDesc(orgId, transactionIds)
                .stream()
                .collect(Collectors.groupingBy(PaymentMatch::getBankTransactionId, LinkedHashMap::new, Collectors.toList()));

        return PagedResponse.from(page.map(tx -> toResponse(
                tx,
                matchMap.getOrDefault(tx.getId(), List.of())
        )));
    }

    @Transactional
    public BankTransactionResponse rerunMatches(UUID transactionId) {
        UUID orgId = requireOrgId();
        BankTransaction transaction = getTransaction(transactionId, orgId);

        // A MATCHED transaction has already settled (payment/journal posted). Re-running
        // would delete only the SUGGESTED rows, leave the ACCEPTED one, re-suggest a fresh
        // match and reset the status to SUGGESTED — defeating the accept-time MATCHED guard
        // and enabling a duplicate posting. Force an explicit un-match first.
        if ("MATCHED".equals(transaction.getStatus())) {
            throw new BusinessException(
                    "Transaction is already matched — reject its match before re-running",
                    "BANK_TX_ALREADY_MATCHED", HttpStatus.CONFLICT);
        }

        paymentMatchRepository.deleteByOrgIdAndBankTransactionIdAndMatchStatus(orgId, transactionId, "SUGGESTED");

        // A re-run re-suggests but never auto-posts (auto-apply is an import-time act).
        Optional<BankRule> rule = bankRuleService.firstMatch(orgId, transaction);
        List<PaymentMatch> matches = rule.isPresent()
                ? List.of(paymentMatchRepository.save(buildAccountMatch(orgId, transaction, rule.get())))
                : buildMatches(orgId, transaction);
        if (!matches.isEmpty()) {
            if (rule.isEmpty()) {
                paymentMatchRepository.saveAll(matches);
            }
            transaction.setStatus("SUGGESTED");
        } else if (!"MATCHED".equals(transaction.getStatus()) && !"IGNORED".equals(transaction.getStatus())) {
            transaction.setStatus("UNMATCHED");
        }
        BankTransaction saved = bankTransactionRepository.save(transaction);
        return toResponse(saved, matches);
    }

    @Transactional
    public BankTransactionResponse ignoreTransaction(UUID transactionId) {
        UUID orgId = requireOrgId();
        BankTransaction transaction = getTransaction(transactionId, orgId);

        // A MATCHED / already-posted transaction must not be flippable to IGNORED:
        // it would strand the ACCEPTED match, and a later re-run → accept would
        // double-post the same physical money (the MATCHED guards elsewhere only
        // fire on status MATCHED, which IGNORED erases). Require an explicit reject
        // of the settled match first.
        if ("MATCHED".equals(transaction.getStatus()) || transaction.getPaymentId() != null) {
            throw new BusinessException(
                    "Transaction is already matched — reject its match before ignoring",
                    "BANK_TX_ALREADY_MATCHED", HttpStatus.CONFLICT);
        }
        transaction.setStatus("IGNORED");

        List<PaymentMatch> matches = paymentMatchRepository
                .findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(orgId, transactionId);
        matches.stream()
                .filter(match -> "SUGGESTED".equals(match.getMatchStatus()))
                .forEach(match -> match.setMatchStatus("REJECTED"));
        paymentMatchRepository.saveAll(matches);

        return toResponse(bankTransactionRepository.save(transaction), matches);
    }

    @Transactional
    public BankTransactionResponse acceptMatch(UUID matchId) {
        return acceptMatch(matchId, null);
    }

    /**
     * Accept a suggested match. {@code bankAccountId} (optional) picks which
     * bank ledger the money-out leg debits — when supplied, the vendor payment
     * is paid through that bank account's GL instead of the org default BANK
     * (1020). Null preserves the legacy single-bank behaviour byte-for-byte.
     */
    @Transactional
    public BankTransactionResponse acceptMatch(UUID matchId, UUID bankAccountId) {
        UUID orgId = requireOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        PaymentMatch match = paymentMatchRepository.findByIdAndOrgId(matchId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PaymentMatch", matchId));

        // Only a still-pending suggestion may be accepted — an already ACCEPTED /
        // REJECTED / IGNORED match must not (re-)post a payment or journal.
        if (!"SUGGESTED".equals(match.getMatchStatus())) {
            throw new BusinessException(
                    "This match is no longer pending (" + match.getMatchStatus() + ")",
                    "BANK_MATCH_NOT_SUGGESTED",
                    HttpStatus.CONFLICT
            );
        }

        // Pessimistic row lock: two concurrent accepts on the same transaction
        // serialise here, so the second reads the first's committed MATCHED status
        // below and is rejected — preventing a double settlement / duplicate journal.
        BankTransaction transaction = bankTransactionRepository
                .findByIdAndOrgIdForUpdate(match.getBankTransactionId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("BankTransaction", match.getBankTransactionId()));

        if ("MATCHED".equals(transaction.getStatus()) || transaction.getPaymentId() != null) {
            // paymentId != null also catches a MATCHED tx that was flipped to
            // IGNORED then re-run (the status is no longer MATCHED but the money
            // was already posted) — refusing on the payment id closes that path.
            throw new BusinessException(
                    "Bank transaction is already matched",
                    "BANK_TX_ALREADY_MATCHED",
                    HttpStatus.CONFLICT
            );
        }

        UUID createdPaymentId;
        if ("ACCOUNT".equals(match.getMatchType())) {
            // Bank-rule categorisation → a direct bank <-> account journal (no
            // invoice/bill/payment). CREDIT (money in): DR bank / CR account;
            // DEBIT (money out): DR account / CR bank.
            createdPaymentId = postAccountJournal(orgId, transaction, match, bankAccountId);
        } else if ("BILL".equals(match.getMatchType())) {
            // Money out → record a vendor payment allocated to the matched bill,
            // paid through the chosen bank account (or the org default BANK).
            UUID paidThroughId = bankAccountId != null
                    ? bankAccountService.resolveGlAccountId(bankAccountId)
                    : defaultAccountService.get(orgId, DefaultAccountPurpose.BANK).getId();
            VendorPaymentResponse vendorPayment = vendorPaymentService.recordPayment(new VendorPaymentRequest(
                    match.getContactId(),
                    match.getMatchedAmount(),
                    inferPaymentMethod(transaction),
                    transaction.getTransactionDate(),
                    paidThroughId,
                    firstNonBlank(transaction.getUtr(), transaction.getNarration()),
                    null,
                    null,
                    "Matched from imported bank transaction",
                    null,
                    List.of(new VendorPaymentRequest.AllocationRequest(
                            match.getBillId(), match.getMatchedAmount()))
            ));
            createdPaymentId = vendorPayment.id();
        } else {
            // Money in → record an AR payment against the matched invoice.
            Payment payment = paymentService.recordPayment(new RecordPaymentRequest(
                    match.getInvoiceId(),
                    match.getContactId(),
                    transaction.getTransactionDate(),
                    match.getMatchedAmount(),
                    inferPaymentMethod(transaction),
                    firstNonBlank(transaction.getUtr(), transaction.getNarration()),
                    transaction.getPayerVpa(),
                    "Matched from imported bank transaction"
            ));
            createdPaymentId = payment.getId();
        }

        match.setMatchStatus("ACCEPTED");
        match.setPaymentId(createdPaymentId);
        match.setAcceptedAt(Instant.now());
        match.setAcceptedBy(userId);
        paymentMatchRepository.save(match);

        List<PaymentMatch> allMatches = paymentMatchRepository
                .findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(orgId, transaction.getId());
        for (PaymentMatch candidate : allMatches) {
            if (!candidate.getId().equals(match.getId())
                    && "SUGGESTED".equals(candidate.getMatchStatus())) {
                candidate.setMatchStatus("REJECTED");
            }
        }
        paymentMatchRepository.saveAll(allMatches);

        transaction.setStatus("MATCHED");
        transaction.setPaymentId(createdPaymentId);
        BankTransaction saved = bankTransactionRepository.save(transaction);
        return toResponse(saved, allMatches);
    }

    @Transactional
    public BankTransactionResponse rejectMatch(UUID matchId) {
        UUID orgId = requireOrgId();
        PaymentMatch match = paymentMatchRepository.findByIdAndOrgId(matchId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PaymentMatch", matchId));
        BankTransaction transaction = getTransaction(match.getBankTransactionId(), orgId);

        match.setMatchStatus("REJECTED");
        paymentMatchRepository.save(match);

        List<PaymentMatch> allMatches = paymentMatchRepository
                .findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(orgId, transaction.getId());
        boolean stillSuggested = allMatches.stream()
                .anyMatch(candidate -> "SUGGESTED".equals(candidate.getMatchStatus()));
        if (!stillSuggested && !"MATCHED".equals(transaction.getStatus())) {
            transaction.setStatus("UNMATCHED");
            transaction = bankTransactionRepository.save(transaction);
        }
        return toResponse(transaction, allMatches);
    }

    private String inferPaymentMethod(BankTransaction transaction) {
        String combined = normalize(transaction.getNarration()) + " " + normalize(transaction.getPayerVpa());
        return combined.contains("upi") || containsLikelyUpiVpa(combined) ? "UPI" : "BANK_TRANSFER";
    }

    private BankTransaction getTransaction(UUID transactionId, UUID orgId) {
        return bankTransactionRepository.findByIdAndOrgId(transactionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("BankTransaction", transactionId));
    }

    // ── Bank-rule (ACCOUNT) categorisation ───────────────────────────────────

    private PaymentMatch buildAccountMatch(UUID orgId, BankTransaction transaction, BankRule rule) {
        return PaymentMatch.builder()
                .orgId(orgId)
                .bankTransactionId(transaction.getId())
                .matchType("ACCOUNT")
                .accountCode(rule.getAccountCode())
                .bankRuleId(rule.getId())
                .contactId(rule.getContactId())
                .matchedAmount(transaction.getAmount().setScale(2, RoundingMode.HALF_UP))
                .confidence(new BigDecimal("0.9900"))
                .matchStatus("SUGGESTED")
                .build();
    }

    /**
     * Post the direct bank &lt;-&gt; account journal for an accepted ACCOUNT match.
     * CREDIT (money in): DR bank / CR account. DEBIT (money out): DR account / CR bank.
     * Returns the posted journal entry id (stored as the transaction's paymentId for audit).
     */
    private UUID postAccountJournal(UUID orgId, BankTransaction transaction,
                                    PaymentMatch match, UUID bankAccountId) {
        String bankCode = resolveBankAccountCode(orgId, bankAccountId);
        String accountCode = match.getAccountCode();
        // The target account may have been deleted between suggest and accept.
        accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, accountCode)
                .orElseThrow(() -> new BusinessException(
                        "Categorisation account " + accountCode + " no longer exists",
                        "BANK_RULE_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST));

        // Pre-validate the fiscal period with a DIRECT repository read (NOT
        // FiscalPeriodService.requireOpen — that is @Transactional, so its throw
        // crosses a proxy boundary and marks the OUTER import tx rollback-only,
        // making the whole statement import fail with UnexpectedRollbackException).
        // Throwing from this same bean lets importRows' catch degrade the row to a
        // suggestion (mirrors the same-bean BANK_RULE_ACCOUNT_MISSING guard above).
        assertPeriodOpenForBankRule(orgId, transaction.getTransactionDate());

        BigDecimal amount = match.getMatchedAmount().setScale(2, RoundingMode.HALF_UP);
        boolean moneyIn = "CREDIT".equalsIgnoreCase(transaction.getDirection());
        String memo = ruleMemo(orgId, match, transaction);

        List<JournalLineRequest> lines = moneyIn
                ? List.of(
                        new JournalLineRequest(bankCode, amount, BigDecimal.ZERO, memo, null, null),
                        new JournalLineRequest(accountCode, BigDecimal.ZERO, amount, memo, null, null))
                : List.of(
                        new JournalLineRequest(accountCode, amount, BigDecimal.ZERO, memo, null, null),
                        new JournalLineRequest(bankCode, BigDecimal.ZERO, amount, memo, null, null));

        JournalEntry entry = journalService.postJournal(new JournalPostRequest(
                transaction.getTransactionDate(), memo, "BANKING", transaction.getId(), lines, true));
        return entry.getId();
    }

    /**
     * Same-bean fiscal-period gate for the bank-rule journal. Reads the period
     * row directly (no @Transactional proxy) and throws ACCT_PERIOD_CLOSED if it
     * is closed, computing the period exactly as JournalService does.
     */
    private void assertPeriodOpenForBankRule(UUID orgId, LocalDate date) {
        int fyStart = organisationRepository.findById(orgId)
                .map(Organisation::getFiscalYearStart)
                .filter(Objects::nonNull)
                .orElse(4);
        int periodYear = date.getMonthValue() >= fyStart ? date.getYear() : date.getYear() - 1;
        int periodMonth = date.getMonthValue();
        fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, periodYear, periodMonth)
                .filter(FiscalPeriod::isClosed)
                .ifPresent(fp -> {
                    throw new BusinessException(
                            "Fiscal period " + periodYear + "-" + String.format("%02d", periodMonth)
                                    + " is closed. Reopen it before posting.",
                            "ACCT_PERIOD_CLOSED", HttpStatus.CONFLICT);
                });
    }

    private String resolveBankAccountCode(UUID orgId, UUID bankAccountId) {
        if (bankAccountId != null) {
            UUID glAccountId = bankAccountService.resolveGlAccountId(bankAccountId);
            return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, glAccountId)
                    .map(Account::getCode)
                    .orElseThrow(() -> new BusinessException("Bank GL account not found",
                            "BANK_GL_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST));
        }
        return defaultAccountService.get(orgId, DefaultAccountPurpose.BANK).getCode();
    }

    private String ruleMemo(UUID orgId, PaymentMatch match, BankTransaction transaction) {
        String memo = bankRuleService.findEntity(orgId, match.getBankRuleId())
                .map(BankRule::getMemo).orElse(null);
        String base = firstNonBlank(memo, transaction.getNarration());
        if (base == null || base.isBlank()) {
            base = firstNonBlank(transaction.getUtr(), "categorisation");
        }
        return "Bank rule: " + base;
    }

    private List<PaymentMatch> buildMatches(UUID orgId, BankTransaction transaction) {
        if ("DEBIT".equalsIgnoreCase(transaction.getDirection())) {
            return buildDebitMatches(orgId, transaction);
        }
        if (!"CREDIT".equalsIgnoreCase(transaction.getDirection())) {
            return List.of();
        }

        BigDecimal txAmount = transaction.getAmount().setScale(2, RoundingMode.HALF_UP);
        List<Invoice> outstanding = invoiceRepository.findOutstandingInvoicesForBankMatching(
                orgId,
                txAmount,
                PageRequest.of(0, MAX_INVOICES_TO_SCORE)
        );
        if (outstanding.isEmpty()) {
            return List.of();
        }

        Set<UUID> contactIds = outstanding.stream()
                .map(Invoice::getContactId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<UUID, Contact> contactMap = contactIds.isEmpty()
                ? Map.of()
                : contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, contactIds)
                .stream()
                .collect(Collectors.toMap(Contact::getId, contact -> contact));

        String normalizedNarration = normalize(transaction.getNarration());
        String normalizedPayerName = normalize(transaction.getPayerName());
        String normalizedPayerVpa = normalize(transaction.getPayerVpa());

        return outstanding.stream()
                .map(invoice -> scoreCandidate(invoice, contactMap.get(invoice.getContactId()), transaction,
                        txAmount, normalizedNarration, normalizedPayerName, normalizedPayerVpa))
                .filter(Objects::nonNull)
                .sorted(Comparator.comparing(Candidate::confidence).reversed())
                .limit(3)
                .map(candidate -> PaymentMatch.builder()
                        .orgId(orgId)
                        .bankTransactionId(transaction.getId())
                        .invoiceId(candidate.invoice().getId())
                        .contactId(candidate.invoice().getContactId())
                        .matchedAmount(candidate.matchedAmount())
                        .confidence(candidate.confidence())
                        .matchStatus("SUGGESTED")
                        .build())
                .toList();
    }

    /** Money out: score open purchase bills the debit could be paying. */
    private List<PaymentMatch> buildDebitMatches(UUID orgId, BankTransaction transaction) {
        BigDecimal txAmount = transaction.getAmount().setScale(2, RoundingMode.HALF_UP);
        List<PurchaseBill> openBills = purchaseBillRepository.findOutstandingBillsForBankMatching(
                orgId, txAmount, PageRequest.of(0, MAX_INVOICES_TO_SCORE));
        if (openBills.isEmpty()) {
            return List.of();
        }

        Set<UUID> contactIds = openBills.stream()
                .map(PurchaseBill::getContactId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<UUID, Contact> contactMap = contactIds.isEmpty()
                ? Map.of()
                : contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, contactIds)
                .stream()
                .collect(Collectors.toMap(Contact::getId, contact -> contact));

        String narration = normalize(transaction.getNarration());

        return openBills.stream()
                .map(bill -> scoreBillCandidate(bill, contactMap.get(bill.getContactId()), txAmount, narration))
                .filter(Objects::nonNull)
                .sorted(Comparator.comparing(BillCandidate::confidence).reversed())
                .limit(3)
                .map(candidate -> PaymentMatch.builder()
                        .orgId(orgId)
                        .bankTransactionId(transaction.getId())
                        .matchType("BILL")
                        .billId(candidate.bill().getId())
                        .contactId(candidate.bill().getContactId())
                        .matchedAmount(candidate.matchedAmount())
                        .confidence(candidate.confidence())
                        .matchStatus("SUGGESTED")
                        .build())
                .toList();
    }

    private BillCandidate scoreBillCandidate(
            PurchaseBill bill,
            Contact vendor,
            BigDecimal txAmount,
            String narration
    ) {
        BigDecimal balanceDue = scale(bill.getBalanceDue());
        BigDecimal matchedAmount = txAmount.min(balanceDue);
        BigDecimal score = BigDecimal.ZERO;

        if (txAmount.compareTo(balanceDue) == 0) {
            score = score.add(new BigDecimal("0.55"));
        } else if (txAmount.compareTo(balanceDue) < 0) {
            score = score.add(new BigDecimal("0.32"));
        } else {
            return null;
        }

        if (bill.getVendorBillNumber() != null
                && !normalize(bill.getVendorBillNumber()).isBlank()
                && narration.contains(normalize(bill.getVendorBillNumber()))) {
            score = score.add(new BigDecimal("0.35"));
        }
        if (vendor != null) {
            String name = normalize(vendor.getDisplayName());
            if (!name.isBlank() && narration.contains(name)) {
                score = score.add(new BigDecimal("0.25"));
            }
        }

        score = score.min(BigDecimal.ONE).setScale(4, RoundingMode.HALF_UP);
        if (score.compareTo(new BigDecimal("0.45")) < 0) {
            return null;
        }
        return new BillCandidate(bill, matchedAmount, score);
    }

    private Candidate scoreCandidate(
            Invoice invoice,
            Contact contact,
            BankTransaction transaction,
            BigDecimal txAmount,
            String normalizedNarration,
            String normalizedPayerName,
            String normalizedPayerVpa
    ) {
        BigDecimal balanceDue = scale(invoice.getBalanceDue());
        BigDecimal score = BigDecimal.ZERO;
        BigDecimal matchedAmount = txAmount.min(balanceDue);

        if (txAmount.compareTo(balanceDue) == 0) {
            score = score.add(new BigDecimal("0.55"));
        } else if (txAmount.compareTo(balanceDue) < 0) {
            score = score.add(new BigDecimal("0.32"));
        } else {
            return null;
        }

        if (normalizedNarration.contains(normalize(invoice.getInvoiceNumber()))) {
            score = score.add(new BigDecimal("0.35"));
        }

        if (contact != null) {
            String displayName = normalize(contact.getDisplayName());
            if (!displayName.isBlank() && (normalizedNarration.contains(displayName)
                    || normalizedPayerName.contains(displayName))) {
                score = score.add(new BigDecimal("0.22"));
            }

            String upiId = normalize(contact.getUpiId());
            if (!upiId.isBlank() && (normalizedPayerVpa.contains(upiId) || normalizedNarration.contains(upiId))) {
                score = score.add(new BigDecimal("0.28"));
            }
        }

        if (transaction.getTransactionDate() != null && invoice.getInvoiceDate() != null
                && !transaction.getTransactionDate().isBefore(invoice.getInvoiceDate().minusDays(5))) {
            score = score.add(new BigDecimal("0.05"));
        }

        score = score.min(BigDecimal.ONE).setScale(4, RoundingMode.HALF_UP);
        if (score.compareTo(new BigDecimal("0.45")) < 0) {
            return null;
        }

        return new Candidate(invoice, matchedAmount, score);
    }

    private BankTransactionResponse toResponse(BankTransaction transaction, List<PaymentMatch> matches) {
        Map<UUID, Invoice> invoiceMap = matches.stream()
                .map(PaymentMatch::getInvoiceId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.collectingAndThen(Collectors.toList(), invoiceIds -> {
                    if (invoiceIds.isEmpty()) {
                        return Map.of();
                    }
                    return invoiceRepository.findAllById(invoiceIds).stream()
                            .filter(invoice -> transaction.getOrgId().equals(invoice.getOrgId()))
                            .collect(Collectors.toMap(Invoice::getId, invoice -> invoice, (left, right) -> left));
                }));

        Set<UUID> contactIds = matches.stream()
                .map(PaymentMatch::getContactId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<UUID, Contact> contactMap = contactIds.isEmpty()
                ? Map.of()
                : contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(transaction.getOrgId(), contactIds)
                .stream()
                .collect(Collectors.toMap(Contact::getId, contact -> contact));

        Map<UUID, PurchaseBill> billMap = matches.stream()
                .map(PaymentMatch::getBillId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.collectingAndThen(Collectors.toList(), billIds -> {
                    if (billIds.isEmpty()) {
                        return Map.of();
                    }
                    return purchaseBillRepository.findAllById(billIds).stream()
                            .filter(bill -> transaction.getOrgId().equals(bill.getOrgId()))
                            .collect(Collectors.toMap(PurchaseBill::getId, bill -> bill, (left, right) -> left));
                }));

        List<PaymentMatchResponse> matchResponses = matches.stream()
                .map(match -> {
                    // Guard the null key: an ACCOUNT (bank-rule) match may carry no contact,
                    // and an immutable Map.of() throws NPE on get(null).
                    Contact contact = match.getContactId() == null
                            ? null : contactMap.get(match.getContactId());
                    String documentNumber;
                    if ("ACCOUNT".equals(match.getMatchType())) {
                        documentNumber = match.getAccountCode();
                    } else if ("BILL".equals(match.getMatchType())) {
                        PurchaseBill bill = billMap.get(match.getBillId());
                        documentNumber = bill != null
                                ? firstNonBlank(bill.getVendorBillNumber(), bill.getBillNumber())
                                : null;
                    } else {
                        Invoice invoice = invoiceMap.get(match.getInvoiceId());
                        documentNumber = invoice != null ? invoice.getInvoiceNumber() : null;
                    }
                    return PaymentMatchResponse.from(
                            match,
                            documentNumber,
                            contact != null ? contact.getDisplayName() : null
                    );
                })
                .toList();
        return BankTransactionResponse.from(transaction, matchResponses);
    }

    private String normalize(String value) {
        return value == null ? "" : value.toLowerCase(Locale.ROOT).replaceAll("\\s+", " ").trim();
    }

    private boolean containsLikelyUpiVpa(String value) {
        if (value == null || value.isBlank()) {
            return false;
        }
        var matcher = UPI_VPA_PATTERN.matcher(value);
        while (matcher.find()) {
            String candidate = matcher.group(2);
            int at = candidate.indexOf('@');
            if (at < 0 || at == candidate.length() - 1) {
                continue;
            }
            String provider = candidate.substring(at + 1).toLowerCase(Locale.ROOT);
            if (!COMMON_EMAIL_DOMAINS.contains(provider)) {
                return true;
            }
        }
        return false;
    }

    private BigDecimal scale(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value.setScale(2, RoundingMode.HALF_UP);
    }

    private String firstNonBlank(String primary, String fallback) {
        if (primary != null && !primary.isBlank()) return primary;
        return fallback;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }

    private record Candidate(
            Invoice invoice,
            BigDecimal matchedAmount,
            BigDecimal confidence
    ) {
    }

    private record BillCandidate(
            PurchaseBill bill,
            BigDecimal matchedAmount,
            BigDecimal confidence
    ) {
    }
}
