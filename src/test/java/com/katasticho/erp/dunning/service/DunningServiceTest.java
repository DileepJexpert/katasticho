package com.katasticho.erp.dunning.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.dunning.dto.DunningDtos.*;
import com.katasticho.erp.dunning.entity.DunningLevel;
import com.katasticho.erp.dunning.entity.DunningLog;
import com.katasticho.erp.dunning.repository.DunningLevelRepository;
import com.katasticho.erp.dunning.repository.DunningLogRepository;
import com.katasticho.erp.notification.EmailService;
import com.katasticho.erp.notification.whatsapp.WhatsAppDocumentService;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.paymentterm.entity.InvoiceInstalment;
import com.katasticho.erp.paymentterm.repository.InvoiceInstalmentRepository;
import com.katasticho.erp.paymentterm.service.PaymentTermService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.dao.DataIntegrityViolationException;

import java.math.BigDecimal;
import java.time.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DunningServiceTest {

    @Mock private DunningLevelRepository levelRepository;
    @Mock private DunningLogRepository logRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private InvoiceInstalmentRepository instalmentRepository;
    @Mock private PaymentTermService paymentTermService;
    @Mock private ContactRepository contactRepository;
    @Mock private EmailService emailService;
    @Mock private WhatsAppDocumentService whatsAppDocumentService;
    @Mock private AiSuggestionService aiSuggestionService;
    @Mock private AiSuggestionRepository aiSuggestionRepository;
    @Mock private OrganisationRepository organisationRepository;

    private DunningService svc;
    private final UUID orgId = UUID.randomUUID();
    private final Clock clock = Clock.fixed(Instant.parse("2026-02-15T00:00:00Z"), ZoneOffset.UTC);
    private final LocalDate today = LocalDate.of(2026, 2, 15);

    @BeforeEach
    void setUp() {
        DunningDispatcher dispatcher = new DunningDispatcher(logRepository, emailService,
                whatsAppDocumentService, aiSuggestionService, aiSuggestionRepository, clock);
        svc = new DunningService(levelRepository, logRepository, invoiceRepository, instalmentRepository,
                paymentTermService, contactRepository, dispatcher, organisationRepository, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(instalmentRepository.findByInvoiceIdAndIsDeletedFalseOrderBySeqAsc(any())).thenReturn(List.of());
        when(instalmentRepository.findInvoiceIdsWithInstalmentDueBefore(any(), any())).thenReturn(List.of());
        when(logRepository.existsByOrgIdAndInvoiceIdAndDunningLevelIdAndOutcomeAndIsDeletedFalse(any(), any(), any(), any()))
                .thenReturn(false);
        when(logRepository.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
        // EMAIL delivery now honours sendHtml's boolean; default to a successful send.
        when(emailService.sendHtml(any(), any(), any())).thenReturn(true);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private DunningLevel level(int seq, String name, int days, String channel) {
        DunningLevel l = DunningLevel.builder().seq(seq).name(name).daysOverdue(days).channel(channel).build();
        l.setId(UUID.randomUUID());
        l.setOrgId(orgId);
        return l;
    }

    private Invoice invoice(int dueOffsetDays, String balance) {
        Invoice inv = new Invoice();
        inv.setId(UUID.randomUUID());
        inv.setOrgId(orgId);
        inv.setContactId(UUID.randomUUID());
        inv.setInvoiceNumber("INV-1");
        inv.setStatus("SENT");
        inv.setDueDate(today.plusDays(dueOffsetDays));
        inv.setAmountPaid(BigDecimal.ZERO);
        inv.setBalanceDue(new BigDecimal(balance));
        inv.setTotalAmount(new BigDecimal(balance));
        return inv;
    }

    private Contact contactWithEmail(UUID id, String email) {
        Contact c = new Contact();
        c.setId(id);
        c.setOrgId(orgId);
        c.setDisplayName("Acme Traders");
        c.setEmail(email);
        return c;
    }

    private void levels(DunningLevel... ls) {
        when(levelRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderBySeqAsc(orgId)).thenReturn(List.of(ls));
    }

    // ── sweep ──

    @Test
    void no_active_levels_is_a_no_op() {
        when(levelRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderBySeqAsc(orgId)).thenReturn(List.of());
        DunningRunResult r = svc.run();
        assertThat(r.sent()).isZero();
        verify(invoiceRepository, never()).findOverdueInvoices(any(), any());
    }

    @Test
    void fires_highest_applicable_level_and_emails() {
        Invoice inv = invoice(-60, "1000"); // 60 days overdue
        levels(level(0, "L1", 7, "EMAIL"), level(1, "L2", 30, "EMAIL"), level(2, "L3", 60, "EMAIL"));
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getContactId(), orgId))
                .thenReturn(Optional.of(contactWithEmail(inv.getContactId(), "a@b.com")));

        DunningRunResult r = svc.run();

        assertThat(r.sent()).isEqualTo(1);
        verify(emailService).sendHtml(eq("a@b.com"), any(), any());
        // the SENT claim was written (claim-before-send) and stamped with the org
        ArgumentCaptor<DunningLog> cap = ArgumentCaptor.forClass(DunningLog.class);
        verify(logRepository).saveAndFlush(cap.capture());
        assertThat(cap.getValue().getOutcome()).isEqualTo("SENT");
        assertThat(cap.getValue().getDaysOverdue()).isEqualTo(60);
        assertThat(cap.getValue().getOrgId()).isEqualTo(orgId);
    }

    @Test
    void picks_the_top_threshold_at_or_below_days_overdue() {
        Invoice inv = invoice(-20, "1000"); // 20 days overdue
        DunningLevel l1 = level(0, "L1", 7, "NONE");
        DunningLevel l2 = level(1, "L2", 30, "NONE");
        levels(l1, l2);
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));

        svc.run();

        ArgumentCaptor<DunningLog> cap = ArgumentCaptor.forClass(DunningLog.class);
        verify(logRepository).saveAndFlush(cap.capture());
        assertThat(cap.getValue().getDunningLevelId()).isEqualTo(l1.getId()); // L2@30 not yet reached
    }

    @Test
    void already_sent_level_is_skipped_without_dispatch() {
        Invoice inv = invoice(-60, "1000");
        DunningLevel l3 = level(2, "L3", 60, "EMAIL");
        levels(level(0, "L1", 7, "EMAIL"), l3);
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));
        when(logRepository.existsByOrgIdAndInvoiceIdAndDunningLevelIdAndOutcomeAndIsDeletedFalse(
                orgId, inv.getId(), l3.getId(), "SENT")).thenReturn(true);

        DunningRunResult r = svc.run();

        assertThat(r.skipped()).isEqualTo(1);
        assertThat(r.sent()).isZero();
        verify(emailService, never()).sendHtml(any(), any(), any());
        verify(logRepository, never()).saveAndFlush(any());
    }

    @Test
    void email_channel_with_no_email_is_skipped_and_claims_nothing() {
        Invoice inv = invoice(-40, "1000");
        levels(level(0, "L1", 30, "EMAIL"));
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getContactId(), orgId))
                .thenReturn(Optional.of(contactWithEmail(inv.getContactId(), null))); // no email

        DunningRunResult r = svc.run();

        assertThat(r.skipped()).isEqualTo(1);
        assertThat(r.sent()).isZero();
        verify(emailService, never()).sendHtml(any(), any(), any());
        verify(logRepository, never()).saveAndFlush(any()); // no claim → retries once email is added
    }

    @Test
    void concurrent_claim_prevents_double_send() {
        // Simulate a competing sweep having already claimed the (invoice, level) SENT
        // slot: the unique-index insert fails BEFORE we send → no duplicate email.
        Invoice inv = invoice(-40, "1000");
        levels(level(0, "L1", 30, "EMAIL"));
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getContactId(), orgId))
                .thenReturn(Optional.of(contactWithEmail(inv.getContactId(), "a@b.com")));
        when(logRepository.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("dup key"));

        DunningRunResult r = svc.run();

        assertThat(r.sent()).isZero();
        assertThat(r.skipped()).isEqualTo(1);
        verify(emailService, never()).sendHtml(any(), any(), any()); // claim failed → never sent
    }

    @Test
    void ai_inbox_creates_suggestion_when_none_open() {
        Invoice inv = invoice(-45, "5000");
        levels(level(0, "L1", 30, "AI_INBOX"));
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getContactId(), orgId))
                .thenReturn(Optional.of(contactWithEmail(inv.getContactId(), "a@b.com")));
        when(aiSuggestionRepository.findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
                eq(orgId), eq("INVOICE"), eq(inv.getId()), eq("DUNNING"), anyList())).thenReturn(Optional.empty());

        DunningRunResult r = svc.run();

        assertThat(r.sent()).isEqualTo(1);
        verify(aiSuggestionService).createSuggestion(any(AiSuggestion.class));
    }

    @Test
    void ai_inbox_escalates_existing_suggestion_in_place() {
        Invoice inv = invoice(-45, "5000");
        levels(level(0, "L1", 30, "AI_INBOX"));
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getContactId(), orgId))
                .thenReturn(Optional.of(contactWithEmail(inv.getContactId(), "a@b.com")));
        AiSuggestion existing = AiSuggestion.builder().priority("MEDIUM").priorityScore(new BigDecimal("55")).build();
        when(aiSuggestionRepository.findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
                eq(orgId), eq("INVOICE"), eq(inv.getId()), eq("DUNNING"), anyList())).thenReturn(Optional.of(existing));

        svc.run();

        verify(aiSuggestionService, never()).createSuggestion(any());
        verify(aiSuggestionRepository).save(existing);
        assertThat(existing.getPriority()).isEqualTo("HIGH"); // 45 days ≥ 30 → HIGH, score 85 > 55 → bumped
    }

    @Test
    void instalment_aware_overdue_pulls_invoice_and_uses_effective_due_date() {
        Invoice inv = invoice(30, "700"); // invoice-level due date in the FUTURE
        inv.setAmountPaid(new BigDecimal("300"));
        DunningLevel l2 = level(1, "L2", 30, "NONE");
        levels(level(0, "L1", 7, "NONE"), l2);
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of());
        when(instalmentRepository.findInvoiceIdsWithInstalmentDueBefore(orgId, today)).thenReturn(List.of(inv.getId()));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getId(), orgId)).thenReturn(Optional.of(inv));
        List<InvoiceInstalment> ins = List.of(InvoiceInstalment.builder().seq(0).amount(new BigDecimal("300")).dueDate(today.minusDays(40)).build());
        when(instalmentRepository.findByInvoiceIdAndIsDeletedFalseOrderBySeqAsc(inv.getId())).thenReturn(ins);
        when(paymentTermService.effectiveDueDate(eq(inv.getAmountPaid()), eq(ins), eq(today)))
                .thenReturn(today.minusDays(40)); // 40 days overdue at instalment level

        DunningRunResult r = svc.run();

        assertThat(r.sent()).isEqualTo(1);
        ArgumentCaptor<DunningLog> cap = ArgumentCaptor.forClass(DunningLog.class);
        verify(logRepository).saveAndFlush(cap.capture());
        assertThat(cap.getValue().getDunningLevelId()).isEqualTo(l2.getId()); // 40 days → L2@30
        assertThat(cap.getValue().getDaysOverdue()).isEqualTo(40);
    }

    @Test
    void not_yet_overdue_is_skipped() {
        Invoice inv = invoice(10, "1000"); // due in the future
        levels(level(0, "L1", 7, "EMAIL"));
        when(invoiceRepository.findOverdueInvoices(orgId, today)).thenReturn(List.of(inv));

        DunningRunResult r = svc.run();

        assertThat(r.sent()).isZero();
        verify(emailService, never()).sendHtml(any(), any(), any());
    }

    // ── level validation ──

    @Test
    void create_level_rejects_bad_channel() {
        LevelRequest req = new LevelRequest(0, "L", 7, "CARRIER_PIGEON", null, null, true);
        assertThatThrownBy(() -> svc.createLevel(req))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "DUNNING_BAD_CHANNEL");
    }

    @Test
    void create_level_rejects_negative_days() {
        LevelRequest req = new LevelRequest(0, "L", -5, "EMAIL", null, null, true);
        assertThatThrownBy(() -> svc.createLevel(req))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "DUNNING_BAD_DAYS");
    }
}
