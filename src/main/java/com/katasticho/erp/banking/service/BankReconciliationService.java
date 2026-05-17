package com.katasticho.erp.banking.service;

import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.banking.dto.BankTransactionImportResponse;
import com.katasticho.erp.banking.dto.BankTransactionResponse;
import com.katasticho.erp.banking.dto.ImportBankTransactionsRequest;
import com.katasticho.erp.banking.dto.PaymentMatchResponse;
import com.katasticho.erp.banking.entity.BankTransaction;
import com.katasticho.erp.banking.entity.PaymentMatch;
import com.katasticho.erp.banking.repository.BankTransactionRepository;
import com.katasticho.erp.banking.repository.PaymentMatchRepository;
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

    private static final Pattern SPLIT_CSV_PATTERN =
            Pattern.compile(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
    private static final Pattern UPI_VPA_PATTERN =
            Pattern.compile("(^|[^A-Za-z0-9._-])([A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9._-]{1,64})(?=$|[^A-Za-z0-9._-])");
    private static final Set<String> COMMON_EMAIL_DOMAINS = Set.of(
            "gmail", "googlemail", "yahoo", "outlook", "hotmail", "live", "icloud", "proton", "protonmail"
    );
    private static final int MAX_INVOICES_TO_SCORE = 200;

    private final BankTransactionRepository bankTransactionRepository;
    private final PaymentMatchRepository paymentMatchRepository;
    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final PaymentService paymentService;

    @Transactional
    public BankTransactionImportResponse importCsv(ImportBankTransactionsRequest request) {
        UUID orgId = requireOrgId();
        List<CsvRow> rows = parseCsv(request.csvText());

        int skipped = 0;
        List<BankTransactionResponse> imported = new ArrayList<>();

        for (CsvRow row : rows) {
            if (row.utr() != null
                    && !row.utr().isBlank()
                    && bankTransactionRepository.existsByOrgIdAndUtrAndDirection(
                            orgId, row.utr(), row.direction())) {
                skipped++;
                continue;
            }

            BankTransaction transaction = bankTransactionRepository.save(
                    BankTransaction.builder()
                            .orgId(orgId)
                            .transactionDate(row.transactionDate())
                            .amount(row.amount())
                            .direction(row.direction())
                            .narration(row.narration())
                            .utr(row.utr())
                            .payerName(row.payerName())
                            .payerVpa(row.payerVpa())
                            .status("UNMATCHED")
                            .build()
            );

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

        paymentMatchRepository.deleteByOrgIdAndBankTransactionIdAndMatchStatus(orgId, transactionId, "SUGGESTED");

        List<PaymentMatch> matches = buildMatches(orgId, transaction);
        if (!matches.isEmpty()) {
            paymentMatchRepository.saveAll(matches);
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
        UUID orgId = requireOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        PaymentMatch match = paymentMatchRepository.findByIdAndOrgId(matchId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PaymentMatch", matchId));
        BankTransaction transaction = getTransaction(match.getBankTransactionId(), orgId);

        if ("MATCHED".equals(transaction.getStatus())) {
            throw new BusinessException(
                    "Bank transaction is already matched",
                    "BANK_TX_ALREADY_MATCHED",
                    HttpStatus.CONFLICT
            );
        }

        RecordPaymentRequest paymentRequest = new RecordPaymentRequest(
                match.getInvoiceId(),
                match.getContactId(),
                transaction.getTransactionDate(),
                match.getMatchedAmount(),
                inferPaymentMethod(transaction),
                firstNonBlank(transaction.getUtr(), transaction.getNarration()),
                transaction.getPayerVpa(),
                "Matched from imported bank transaction"
        );

        Payment payment = paymentService.recordPayment(paymentRequest);

        match.setMatchStatus("ACCEPTED");
        match.setPaymentId(payment.getId());
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
        transaction.setPaymentId(payment.getId());
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

    private List<PaymentMatch> buildMatches(UUID orgId, BankTransaction transaction) {
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

        List<PaymentMatchResponse> matchResponses = matches.stream()
                .map(match -> {
                    Invoice invoice = invoiceMap.get(match.getInvoiceId());
                    Contact contact = contactMap.get(match.getContactId());
                    return PaymentMatchResponse.from(
                            match,
                            invoice != null ? invoice.getInvoiceNumber() : null,
                            contact != null ? contact.getDisplayName() : null
                    );
                })
                .toList();
        return BankTransactionResponse.from(transaction, matchResponses);
    }

    private List<CsvRow> parseCsv(String csvText) {
        List<String> lines = csvText.lines()
                .map(String::trim)
                .filter(line -> !line.isBlank())
                .toList();
        if (lines.size() < 2) {
            throw new BusinessException(
                    "CSV must include a header row and at least one transaction row",
                    "BANK_RECON_INVALID_CSV"
            );
        }

        Map<String, Integer> indexMap = headerIndex(lines.getFirst());
        List<CsvRow> rows = new ArrayList<>();
        for (int i = 1; i < lines.size(); i++) {
            String[] cols = splitCsv(lines.get(i));
            LocalDate date = parseDate(value(cols, indexMap, "date"));
            BigDecimal rawAmount = new BigDecimal(value(cols, indexMap, "amount").replace(",", "").trim());
            String direction = Optional.ofNullable(value(cols, indexMap, "direction"))
                    .map(String::trim)
                    .filter(s -> !s.isBlank())
                    .map(String::toUpperCase)
                    .orElse(rawAmount.signum() >= 0 ? "CREDIT" : "DEBIT");
            rows.add(new CsvRow(
                    date,
                    rawAmount.abs().setScale(2, RoundingMode.HALF_UP),
                    direction,
                    value(cols, indexMap, "narration"),
                    value(cols, indexMap, "utr"),
                    value(cols, indexMap, "payername"),
                    value(cols, indexMap, "payervpa")
            ));
        }
        return rows;
    }

    private Map<String, Integer> headerIndex(String headerLine) {
        String[] headers = splitCsv(headerLine);
        Map<String, Integer> indexMap = new HashMap<>();
        for (int i = 0; i < headers.length; i++) {
            indexMap.put(normalizeHeader(headers[i]), i);
        }
        List<String> required = List.of("date", "amount", "narration");
        for (String key : required) {
            if (!indexMap.containsKey(key)) {
                throw new BusinessException(
                        "CSV header must include: date, amount, narration",
                        "BANK_RECON_INVALID_HEADER"
                );
            }
        }
        return indexMap;
    }

    private String normalizeHeader(String value) {
        return value == null ? "" : value.replaceAll("[^A-Za-z]", "").toLowerCase(Locale.ROOT);
    }

    private String[] splitCsv(String line) {
        return Arrays.stream(SPLIT_CSV_PATTERN.split(line, -1))
                .map(this::unquote)
                .toArray(String[]::new);
    }

    private String unquote(String value) {
        String trimmed = value == null ? "" : value.trim();
        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length() >= 2) {
            return trimmed.substring(1, trimmed.length() - 1).replace("\"\"", "\"");
        }
        return trimmed;
    }

    private String value(String[] cols, Map<String, Integer> indexMap, String key) {
        Integer index = indexMap.get(key);
        if (index == null || index >= cols.length) {
            return null;
        }
        return cols[index];
    }

    private LocalDate parseDate(String value) {
        if (value == null || value.isBlank()) {
            throw new BusinessException("Transaction date is required", "BANK_RECON_INVALID_ROW");
        }
        List<String> patterns = List.of("yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy");
        for (String pattern : patterns) {
            try {
                return LocalDate.parse(value, java.time.format.DateTimeFormatter.ofPattern(pattern));
            } catch (Exception ignored) {
            }
        }
        throw new BusinessException("Unsupported date format: " + value, "BANK_RECON_INVALID_ROW");
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

    private record CsvRow(
            LocalDate transactionDate,
            BigDecimal amount,
            String direction,
            String narration,
            String utr,
            String payerName,
            String payerVpa
    ) {
    }

    private record Candidate(
            Invoice invoice,
            BigDecimal matchedAmount,
            BigDecimal confidence
    ) {
    }
}
