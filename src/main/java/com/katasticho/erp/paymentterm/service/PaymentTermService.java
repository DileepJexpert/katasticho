package com.katasticho.erp.paymentterm.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.paymentterm.dto.PaymentTermDtos.*;
import com.katasticho.erp.paymentterm.entity.InvoiceInstalment;
import com.katasticho.erp.paymentterm.entity.PaymentTerm;
import com.katasticho.erp.paymentterm.entity.PaymentTermLine;
import com.katasticho.erp.paymentterm.repository.InvoiceInstalmentRepository;
import com.katasticho.erp.paymentterm.repository.PaymentTermLineRepository;
import com.katasticho.erp.paymentterm.repository.PaymentTermRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Payment terms (named instalment schedules) + the derived per-instalment view.
 *
 * <p>Applying a term materialises {@code invoice_instalment} rows and sets the
 * invoice's {@code dueDate} to the FINAL instalment. Per-instalment paid/overdue
 * status is never stored — it is derived on read from the invoice's existing
 * {@code amountPaid} via an oldest-first waterfall, so the payment/allocation
 * engine is untouched and a payment is never split across dated sub-balances.
 */
@Service
@RequiredArgsConstructor
public class PaymentTermService {

    private static final BigDecimal HUNDRED = new BigDecimal("100");
    private static final int MAX_LINES = 24;

    private final PaymentTermRepository termRepository;
    private final PaymentTermLineRepository lineRepository;
    private final InvoiceInstalmentRepository instalmentRepository;
    private final InvoiceRepository invoiceRepository;
    private final Clock clock;

    // ── Term CRUD ────────────────────────────────────────────────────────────

    @Transactional
    public PaymentTermResponse create(PaymentTermRequest req) {
        validate(req);
        UUID orgId = TenantContext.getCurrentOrgId();
        PaymentTerm term = termRepository.save(PaymentTerm.builder()
                .name(req.name().trim())
                .description(req.description())
                .isDefault(Boolean.TRUE.equals(req.isDefault()))
                .active(req.active() == null || req.active())
                .build());
        saveLines(term.getId(), orgId, req.lines());
        return toResponse(term);
    }

    @Transactional
    public PaymentTermResponse update(UUID id, PaymentTermRequest req) {
        validate(req);
        PaymentTerm term = load(id);
        term.setName(req.name().trim());
        term.setDescription(req.description());
        term.setDefault(Boolean.TRUE.equals(req.isDefault()));
        term.setActive(req.active() == null || req.active());
        termRepository.save(term);
        lineRepository.deleteByPaymentTermId(term.getId());
        saveLines(term.getId(), term.getOrgId(), req.lines());
        return toResponse(term);
    }

    @Transactional
    public void delete(UUID id) {
        PaymentTerm term = load(id);
        term.setDeleted(true);
        termRepository.save(term);
    }

    @Transactional(readOnly = true)
    public PaymentTermResponse get(UUID id) {
        return toResponse(load(id));
    }

    @Transactional(readOnly = true)
    public List<PaymentTermResponse> list(boolean activeOnly) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<PaymentTerm> terms = activeOnly
                ? termRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByNameAsc(orgId)
                : termRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId);
        return terms.stream().map(this::toResponse).toList();
    }

    // ── Apply a term to an invoice ───────────────────────────────────────────

    @Transactional
    public InstalmentScheduleResponse applyToInvoice(UUID invoiceId, UUID paymentTermId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
        // Re-generating a schedule after money has landed would desync the derived
        // waterfall from reality — only allow it while the invoice is untouched.
        if (invoice.getAmountPaid() != null && invoice.getAmountPaid().signum() > 0) {
            throw new BusinessException("Cannot change instalments on a part-paid invoice",
                    "INSTALMENT_INVOICE_ALREADY_PAID", HttpStatus.BAD_REQUEST);
        }
        BigDecimal total = invoice.getTotalAmount() == null ? BigDecimal.ZERO : invoice.getTotalAmount();
        if (total.signum() <= 0) {
            throw new BusinessException("Invoice total must be positive to schedule instalments",
                    "INSTALMENT_INVOICE_ZERO_TOTAL", HttpStatus.BAD_REQUEST);
        }
        PaymentTerm term = load(paymentTermId);
        List<PaymentTermLine> lines = lineRepository.findByPaymentTermIdAndIsDeletedFalseOrderBySeqAsc(paymentTermId);
        if (lines.isEmpty()) {
            throw new BusinessException("Payment term has no lines", "PAYMENT_TERM_NO_LINES", HttpStatus.BAD_REQUEST);
        }

        instalmentRepository.deleteByInvoiceId(invoiceId);
        List<Scheduled> schedule = computeSchedule(lines, invoice.getInvoiceDate(), total);
        List<InvoiceInstalment> saved = new ArrayList<>();
        for (Scheduled s : schedule) {
            saved.add(instalmentRepository.save(InvoiceInstalment.builder()
                    .invoiceId(invoiceId)
                    .paymentTermId(paymentTermId)
                    .seq(s.seq())
                    .amount(s.amount())
                    .dueDate(s.dueDate())
                    .build()));
        }
        // The invoice's single due_date column mirrors the FINAL instalment so the
        // legacy invoice-level view is conservative; per-instalment overdue is the
        // dunning engine's job.
        invoice.setDueDate(schedule.get(schedule.size() - 1).dueDate());
        invoiceRepository.save(invoice);
        return buildSchedule(invoice, saved);
    }

    @Transactional
    public void clearInstalments(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
        if (invoice.getAmountPaid() != null && invoice.getAmountPaid().signum() > 0) {
            throw new BusinessException("Cannot change instalments on a part-paid invoice",
                    "INSTALMENT_INVOICE_ALREADY_PAID", HttpStatus.BAD_REQUEST);
        }
        instalmentRepository.deleteByInvoiceId(invoiceId);
    }

    @Transactional(readOnly = true)
    public InstalmentScheduleResponse getSchedule(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
        return buildSchedule(invoice, instalmentRepository.findByInvoiceIdAndIsDeletedFalseOrderBySeqAsc(invoiceId));
    }

    // ── Schedule computation (pure) ──────────────────────────────────────────

    /** One computed instalment before persistence. */
    public record Scheduled(int seq, BigDecimal amount, LocalDate dueDate) {}

    /**
     * Split {@code total} across {@code lines} (sorted by seq). Each non-final
     * PERCENT line takes its rounded cut; the FINAL line takes the exact remainder
     * (so Σ instalments == total to the paisa, and a trailing BALANCE line — or
     * plain rounding residue on an all-percent term — is absorbed cleanly).
     */
    public List<Scheduled> computeSchedule(List<PaymentTermLine> lines, LocalDate invoiceDate, BigDecimal total) {
        List<PaymentTermLine> ordered = lines.stream()
                .sorted((a, b) -> Integer.compare(a.getSeq(), b.getSeq())).toList();
        List<Scheduled> out = new ArrayList<>();
        BigDecimal running = BigDecimal.ZERO;
        for (int i = 0; i < ordered.size(); i++) {
            PaymentTermLine line = ordered.get(i);
            LocalDate due = invoiceDate.plusDays(line.getDaysOffset());
            BigDecimal amount;
            if (i == ordered.size() - 1) {
                amount = total.subtract(running); // remainder — exact, absorbs rounding + BALANCE
            } else {
                amount = total.multiply(nz(line.getValue()))
                        .divide(HUNDRED, 2, RoundingMode.HALF_UP);
                running = running.add(amount);
            }
            // Use the ordered position as the instalment seq so it is always 0..n-1
            // distinct (uq_invoice_instalment_seq), regardless of the line's own seq.
            out.add(new Scheduled(i, amount, due));
        }
        return out;
    }

    /**
     * Derive per-instalment paid/overdue status from the invoice's total
     * {@code amountPaid} using an oldest-first waterfall.
     */
    public List<InstalmentView> deriveStatus(BigDecimal amountPaid, List<InvoiceInstalment> instalments, LocalDate today) {
        List<InvoiceInstalment> ordered = instalments.stream()
                .sorted((a, b) -> Integer.compare(a.getSeq(), b.getSeq())).toList();
        BigDecimal running = amountPaid == null ? BigDecimal.ZERO : amountPaid.max(BigDecimal.ZERO);
        List<InstalmentView> views = new ArrayList<>();
        for (InvoiceInstalment inst : ordered) {
            BigDecimal amount = nz(inst.getAmount());
            BigDecimal covered = running.min(amount).max(BigDecimal.ZERO);
            BigDecimal balance = amount.subtract(covered);
            String status = covered.compareTo(amount) >= 0 ? "PAID"
                    : (covered.signum() > 0 ? "PARTIAL" : "PENDING");
            boolean overdue = !"PAID".equals(status) && inst.getDueDate().isBefore(today);
            views.add(new InstalmentView(inst.getId(), inst.getSeq(), amount, inst.getDueDate(),
                    covered, balance, status, overdue));
            running = running.subtract(covered);
        }
        return views;
    }

    /** Earliest not-fully-paid instalment's due date, else null (all covered / none). */
    public LocalDate effectiveDueDate(BigDecimal amountPaid, List<InvoiceInstalment> instalments, LocalDate today) {
        for (InstalmentView v : deriveStatus(amountPaid, instalments, today)) {
            if (!"PAID".equals(v.status())) {
                return v.dueDate();
            }
        }
        return null;
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private InstalmentScheduleResponse buildSchedule(Invoice invoice, List<InvoiceInstalment> instalments) {
        LocalDate today = LocalDate.now(clock);
        List<InstalmentView> views = deriveStatus(invoice.getAmountPaid(), instalments, today);
        boolean allPaid = !views.isEmpty() && views.stream().allMatch(v -> "PAID".equals(v.status()));
        LocalDate eff = effectiveDueDate(invoice.getAmountPaid(), instalments, today);
        UUID termId = instalments.isEmpty() ? null : instalments.get(0).getPaymentTermId();
        return new InstalmentScheduleResponse(invoice.getId(), termId, invoice.getTotalAmount(),
                invoice.getAmountPaid(), allPaid, eff, views);
    }

    private void saveLines(UUID termId, UUID orgId, List<LineRequest> lines) {
        int seq = 0;
        for (LineRequest l : lines) {
            // Always assign the list-position index — a client-supplied seq could
            // duplicate and later collide on uq_invoice_instalment_seq at apply time.
            lineRepository.save(PaymentTermLine.builder()
                    .paymentTermId(termId)
                    .seq(seq)
                    .valueType(normaliseType(l.valueType()))
                    .value(nz(l.value()))
                    .daysOffset(l.daysOffset() == null ? 0 : l.daysOffset())
                    .build());
            seq++;
        }
    }

    private void validate(PaymentTermRequest req) {
        if (req.name() == null || req.name().isBlank()) {
            throw new BusinessException("Name is required", "PAYMENT_TERM_NAME_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        List<LineRequest> lines = req.lines();
        if (lines == null || lines.isEmpty()) {
            throw new BusinessException("At least one line is required", "PAYMENT_TERM_NO_LINES", HttpStatus.BAD_REQUEST);
        }
        if (lines.size() > MAX_LINES) {
            throw new BusinessException("Too many instalment lines", "PAYMENT_TERM_TOO_MANY_LINES", HttpStatus.BAD_REQUEST);
        }
        BigDecimal percentSum = BigDecimal.ZERO;
        boolean sawBalance = false;
        for (int i = 0; i < lines.size(); i++) {
            LineRequest l = lines.get(i);
            String type = normaliseType(l.valueType());
            if (l.daysOffset() != null && l.daysOffset() < 0) {
                throw new BusinessException("days offset cannot be negative", "PAYMENT_TERM_BAD_OFFSET", HttpStatus.BAD_REQUEST);
            }
            if ("BALANCE".equals(type)) {
                if (i != lines.size() - 1) {
                    throw new BusinessException("BALANCE must be the last line", "PAYMENT_TERM_BALANCE_NOT_LAST", HttpStatus.BAD_REQUEST);
                }
                sawBalance = true;
            } else { // PERCENT
                BigDecimal v = nz(l.value());
                if (v.signum() <= 0 || v.compareTo(HUNDRED) > 0) {
                    throw new BusinessException("percent must be between 0 and 100", "PAYMENT_TERM_BAD_PERCENT", HttpStatus.BAD_REQUEST);
                }
                percentSum = percentSum.add(v);
            }
        }
        if (sawBalance) {
            if (percentSum.compareTo(HUNDRED) >= 0) {
                throw new BusinessException("percent lines must total under 100 when a BALANCE line is present",
                        "PAYMENT_TERM_PERCENT_OVER", HttpStatus.BAD_REQUEST);
            }
        } else if (percentSum.compareTo(HUNDRED) > 0
                || HUNDRED.subtract(percentSum).compareTo(new BigDecimal("0.01")) > 0) {
            // Reject any sum OVER 100 (else the remainder-takes-the-rest last line could
            // go negative) and any sum more than 0.01 UNDER 100 (a likely missing line).
            throw new BusinessException("percent lines must total 100 (or add a BALANCE line)",
                    "PAYMENT_TERM_PERCENT_SUM", HttpStatus.BAD_REQUEST);
        }
    }

    private static String normaliseType(String t) {
        String up = t == null ? "PERCENT" : t.trim().toUpperCase();
        if (!"PERCENT".equals(up) && !"BALANCE".equals(up)) {
            throw new BusinessException("Unknown line type: " + t, "PAYMENT_TERM_BAD_TYPE", HttpStatus.BAD_REQUEST);
        }
        return up;
    }

    private PaymentTerm load(UUID id) {
        return termRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Payment term", id));
    }

    private PaymentTermResponse toResponse(PaymentTerm term) {
        List<LineResponse> lines = lineRepository
                .findByPaymentTermIdAndIsDeletedFalseOrderBySeqAsc(term.getId()).stream()
                .map(l -> new LineResponse(l.getId(), l.getSeq(), l.getValueType(), l.getValue(), l.getDaysOffset()))
                .toList();
        return new PaymentTermResponse(term.getId(), term.getName(), term.getDescription(),
                term.isDefault(), term.isActive(), lines);
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
