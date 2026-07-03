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
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PaymentTermServiceTest {

    @Mock private PaymentTermRepository termRepository;
    @Mock private PaymentTermLineRepository lineRepository;
    @Mock private InvoiceInstalmentRepository instalmentRepository;
    @Mock private InvoiceRepository invoiceRepository;

    private PaymentTermService svc;
    private final UUID orgId = UUID.randomUUID();
    private final Clock clock = Clock.fixed(Instant.parse("2026-02-15T00:00:00Z"), ZoneOffset.UTC);
    private final LocalDate today = LocalDate.of(2026, 2, 15);

    @BeforeEach
    void setUp() {
        svc = new PaymentTermService(termRepository, lineRepository, instalmentRepository, invoiceRepository, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(termRepository.save(any())).thenAnswer(i -> {
            PaymentTerm t = i.getArgument(0);
            if (t.getId() == null) t.setId(UUID.randomUUID());
            return t;
        });
        when(lineRepository.save(any())).thenAnswer(i -> {
            PaymentTermLine l = i.getArgument(0);
            if (l.getId() == null) l.setId(UUID.randomUUID());
            return l;
        });
        when(instalmentRepository.save(any())).thenAnswer(i -> {
            InvoiceInstalment x = i.getArgument(0);
            if (x.getId() == null) x.setId(UUID.randomUUID());
            return x;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private PaymentTermLine line(int seq, String type, String value, int days) {
        return PaymentTermLine.builder().seq(seq).valueType(type)
                .value(new BigDecimal(value)).daysOffset(days).build();
    }

    private InvoiceInstalment inst(int seq, String amount, LocalDate due) {
        InvoiceInstalment i = InvoiceInstalment.builder().seq(seq).amount(new BigDecimal(amount)).dueDate(due).build();
        i.setId(UUID.randomUUID());
        return i;
    }

    // ── computeSchedule (pure) ──

    @Test
    void schedule_percent_lines_put_remainder_on_last() {
        List<PaymentTermLine> lines = List.of(
                line(0, "PERCENT", "30", 0), line(1, "PERCENT", "30", 30), line(2, "PERCENT", "40", 60));
        var out = svc.computeSchedule(lines, LocalDate.of(2026, 1, 1), new BigDecimal("1000"));
        assertThat(out).hasSize(3);
        assertThat(out.get(0).amount()).isEqualByComparingTo("300");
        assertThat(out.get(1).amount()).isEqualByComparingTo("300");
        assertThat(out.get(2).amount()).isEqualByComparingTo("400"); // 1000 - 600
        assertThat(out.get(0).dueDate()).isEqualTo(LocalDate.of(2026, 1, 1));
        assertThat(out.get(2).dueDate()).isEqualTo(LocalDate.of(2026, 3, 2)); // +60 days
        // Σ == total exactly
        assertThat(out.stream().map(PaymentTermService.Scheduled::amount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)).isEqualByComparingTo("1000");
    }

    @Test
    void schedule_rounding_residue_absorbed_by_balance_line() {
        List<PaymentTermLine> lines = List.of(
                line(0, "PERCENT", "33.33", 0), line(1, "PERCENT", "33.33", 15), line(2, "BALANCE", "0", 30));
        var out = svc.computeSchedule(lines, LocalDate.of(2026, 1, 1), new BigDecimal("100"));
        assertThat(out.get(0).amount()).isEqualByComparingTo("33.33");
        assertThat(out.get(1).amount()).isEqualByComparingTo("33.33");
        assertThat(out.get(2).amount()).isEqualByComparingTo("33.34"); // 100 - 66.66
        assertThat(out.stream().map(PaymentTermService.Scheduled::amount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)).isEqualByComparingTo("100");
    }

    @Test
    void schedule_single_full_line() {
        var out = svc.computeSchedule(List.of(line(0, "PERCENT", "100", 30)),
                LocalDate.of(2026, 1, 1), new BigDecimal("500"));
        assertThat(out).hasSize(1);
        assertThat(out.get(0).amount()).isEqualByComparingTo("500");
        assertThat(out.get(0).dueDate()).isEqualTo(LocalDate.of(2026, 1, 31));
    }

    // ── deriveStatus (waterfall) ──

    @Test
    void derive_status_waterfalls_amount_paid_oldest_first() {
        List<InvoiceInstalment> ins = List.of(
                inst(0, "400", today.minusDays(20)),  // past
                inst(1, "300", today.minusDays(5)),   // past
                inst(2, "300", today.plusDays(25)));  // future
        var views = svc.deriveStatus(new BigDecimal("500"), ins, today);
        assertThat(views.get(0).status()).isEqualTo("PAID");
        assertThat(views.get(0).overdue()).isFalse();
        assertThat(views.get(1).status()).isEqualTo("PARTIAL");
        assertThat(views.get(1).paidAmount()).isEqualByComparingTo("100");
        assertThat(views.get(1).balance()).isEqualByComparingTo("200");
        assertThat(views.get(1).overdue()).isTrue(); // due in the past + not fully paid
        assertThat(views.get(2).status()).isEqualTo("PENDING");
        assertThat(views.get(2).overdue()).isFalse(); // due in the future
    }

    @Test
    void derive_status_all_paid_when_covered() {
        List<InvoiceInstalment> ins = List.of(
                inst(0, "400", today.minusDays(20)), inst(1, "600", today.minusDays(5)));
        var views = svc.deriveStatus(new BigDecimal("1000"), ins, today);
        assertThat(views).allMatch(v -> "PAID".equals(v.status()));
        assertThat(views).noneMatch(InstalmentView::overdue);
    }

    @Test
    void effective_due_date_is_earliest_unpaid() {
        List<InvoiceInstalment> ins = List.of(
                inst(0, "400", LocalDate.of(2026, 1, 10)),
                inst(1, "300", LocalDate.of(2026, 2, 10)),
                inst(2, "300", LocalDate.of(2026, 3, 10)));
        // 400 paid → inst0 covered → earliest unpaid is inst1
        assertThat(svc.effectiveDueDate(new BigDecimal("400"), ins, today)).isEqualTo(LocalDate.of(2026, 2, 10));
        // fully paid → null
        assertThat(svc.effectiveDueDate(new BigDecimal("1000"), ins, today)).isNull();
        // nothing paid → inst0
        assertThat(svc.effectiveDueDate(BigDecimal.ZERO, ins, today)).isEqualTo(LocalDate.of(2026, 1, 10));
    }

    // ── applyToInvoice ──

    private Invoice invoice(String total, String paid) {
        Invoice inv = new Invoice();
        inv.setId(UUID.randomUUID());
        inv.setOrgId(orgId);
        inv.setInvoiceNumber("INV-1");
        inv.setInvoiceDate(LocalDate.of(2026, 1, 1));
        inv.setDueDate(LocalDate.of(2026, 1, 31));
        inv.setStatus("SENT");
        inv.setTotalAmount(new BigDecimal(total));
        inv.setAmountPaid(new BigDecimal(paid));
        inv.setBalanceDue(new BigDecimal(total).subtract(new BigDecimal(paid)));
        return inv;
    }

    @Test
    void apply_generates_instalments_and_sets_due_date_to_final() {
        Invoice inv = invoice("1000", "0");
        UUID termId = UUID.randomUUID();
        PaymentTerm term = PaymentTerm.builder().name("30/70").build();
        term.setId(termId);
        term.setOrgId(orgId);
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getId(), orgId)).thenReturn(Optional.of(inv));
        when(termRepository.findByIdAndOrgIdAndIsDeletedFalse(termId, orgId)).thenReturn(Optional.of(term));
        when(lineRepository.findByPaymentTermIdAndIsDeletedFalseOrderBySeqAsc(termId)).thenReturn(List.of(
                line(0, "PERCENT", "30", 0), line(1, "PERCENT", "70", 30)));

        InstalmentScheduleResponse res = svc.applyToInvoice(inv.getId(), termId);

        verify(instalmentRepository).deleteByInvoiceId(inv.getId());
        verify(instalmentRepository, times(2)).save(any());
        assertThat(res.instalments()).hasSize(2);
        assertThat(res.instalments().get(0).amount()).isEqualByComparingTo("300");
        assertThat(res.instalments().get(1).amount()).isEqualByComparingTo("700");
        // invoice due date advanced to the FINAL instalment (Jan 1 + 30 days)
        assertThat(inv.getDueDate()).isEqualTo(LocalDate.of(2026, 1, 31));
        verify(invoiceRepository).save(inv);
    }

    @Test
    void apply_rejects_part_paid_invoice() {
        Invoice inv = invoice("1000", "250");
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getId(), orgId)).thenReturn(Optional.of(inv));
        assertThatThrownBy(() -> svc.applyToInvoice(inv.getId(), UUID.randomUUID()))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "INSTALMENT_INVOICE_ALREADY_PAID");
        verify(instalmentRepository, never()).save(any());
    }

    @Test
    void apply_rejects_zero_total() {
        Invoice inv = invoice("0", "0");
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getId(), orgId)).thenReturn(Optional.of(inv));
        assertThatThrownBy(() -> svc.applyToInvoice(inv.getId(), UUID.randomUUID()))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "INSTALMENT_INVOICE_ZERO_TOTAL");
    }

    // ── term validation ──

    @Test
    void create_rejects_percent_sum_not_100_without_balance() {
        PaymentTermRequest req = new PaymentTermRequest("bad", null, false, true, List.of(
                new LineRequest(0, "PERCENT", new BigDecimal("30"), 0),
                new LineRequest(1, "PERCENT", new BigDecimal("30"), 30)));
        assertThatThrownBy(() -> svc.create(req))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "PAYMENT_TERM_PERCENT_SUM");
    }

    @Test
    void create_rejects_balance_line_not_last() {
        PaymentTermRequest req = new PaymentTermRequest("bad", null, false, true, List.of(
                new LineRequest(0, "BALANCE", BigDecimal.ZERO, 0),
                new LineRequest(1, "PERCENT", new BigDecimal("40"), 30)));
        assertThatThrownBy(() -> svc.create(req))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "PAYMENT_TERM_BALANCE_NOT_LAST");
    }

    @Test
    void create_happy_path_persists_term_and_lines() {
        PaymentTermRequest req = new PaymentTermRequest("50/50", "half now half later", false, true, List.of(
                new LineRequest(0, "PERCENT", new BigDecimal("50"), 0),
                new LineRequest(1, "PERCENT", new BigDecimal("50"), 30)));
        when(lineRepository.findByPaymentTermIdAndIsDeletedFalseOrderBySeqAsc(any())).thenReturn(List.of());
        PaymentTermResponse res = svc.create(req);
        assertThat(res.name()).isEqualTo("50/50");
        verify(termRepository).save(any());
        verify(lineRepository, times(2)).save(any());
    }

    @Test
    void create_rejects_percent_sum_just_over_100() {
        // 100.01 — the OLD symmetric ±0.01 tolerance accepted this (→ a negative final
        // instalment was possible); the strict over-100 guard now rejects it.
        PaymentTermRequest req = new PaymentTermRequest("over", null, false, true, List.of(
                new LineRequest(0, "PERCENT", new BigDecimal("50"), 0),
                new LineRequest(1, "PERCENT", new BigDecimal("50.01"), 30)));
        assertThatThrownBy(() -> svc.create(req))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "PAYMENT_TERM_PERCENT_SUM");
    }

    @Test
    void create_accepts_thirds_summing_to_99_99() {
        PaymentTermRequest req = new PaymentTermRequest("thirds", null, false, true, List.of(
                new LineRequest(0, "PERCENT", new BigDecimal("33.33"), 0),
                new LineRequest(1, "PERCENT", new BigDecimal("33.33"), 30),
                new LineRequest(2, "PERCENT", new BigDecimal("33.33"), 60)));
        when(lineRepository.findByPaymentTermIdAndIsDeletedFalseOrderBySeqAsc(any())).thenReturn(List.of());
        assertThatCode(() -> svc.create(req)).doesNotThrowAnyException();
    }

    @Test
    void schedule_seqs_are_ordered_positions_even_with_duplicate_line_seq() {
        // Duplicate client-supplied seq must NOT leak into instalment seq (else it would
        // collide on uq_invoice_instalment_seq at apply time).
        List<PaymentTermLine> lines = List.of(
                line(5, "PERCENT", "50", 0), line(5, "PERCENT", "50", 30));
        var out = svc.computeSchedule(lines, LocalDate.of(2026, 1, 1), new BigDecimal("1000"));
        assertThat(out).extracting(PaymentTermService.Scheduled::seq).containsExactly(0, 1);
    }
}
