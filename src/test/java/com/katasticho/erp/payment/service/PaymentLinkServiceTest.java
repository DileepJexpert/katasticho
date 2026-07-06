package com.katasticho.erp.payment.service;

import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentForInvoiceRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.payment.entity.PaymentLink;
import com.katasticho.erp.payment.repository.PaymentLinkRepository;
import com.katasticho.erp.payment.repository.PaymentWebhookEventRepository;
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
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PaymentLinkServiceTest {

    @Mock private RazorpayClient razorpayClient;
    @Mock private PaymentLinkRepository paymentLinkRepository;
    @Mock private PaymentWebhookEventRepository webhookEventRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private PaymentService paymentService;
    @Mock private com.katasticho.erp.ai.service.AiSuggestionService aiSuggestionService;
    @Mock private com.katasticho.erp.ai.repository.AiSuggestionRepository aiSuggestionRepository;
    @Mock private com.katasticho.erp.auth.repository.AppUserRepository appUserRepository;
    @Mock private jakarta.persistence.EntityManager entityManager;

    private PaymentLinkService svc;
    private final UUID orgId = UUID.randomUUID();
    private final UUID invoiceId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(LocalDate.of(2026, 7, 2).atStartOfDay(ZoneId.systemDefault()).toInstant(),
                ZoneId.systemDefault());
        svc = new PaymentLinkService(razorpayClient, paymentLinkRepository, webhookEventRepository,
                invoiceRepository, contactRepository, paymentService, aiSuggestionService,
                aiSuggestionRepository, appUserRepository, entityManager, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(paymentLinkRepository.save(any())).thenAnswer(i -> {
            PaymentLink l = i.getArgument(0);
            if (l.getId() == null) l.setId(UUID.randomUUID());
            return l;
        });
        when(webhookEventRepository.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Invoice payableInvoice(String balance) {
        Invoice inv = new Invoice();
        inv.setId(invoiceId);
        inv.setOrgId(orgId);
        inv.setInvoiceNumber("INV-001");
        inv.setStatus("SENT");
        inv.setCurrency("INR");
        inv.setBalanceDue(new BigDecimal(balance));
        inv.setContactId(UUID.randomUUID());
        return inv;
    }

    // ── create ──

    @Test
    void createForInvoice_builds_paise_amount_and_reference_id() {
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(payableInvoice("500.00")));
        when(razorpayClient.createPaymentLink(eq(orgId), anyLong(), anyString(), anyString(),
                anyString(), any(), any(), any()))
                .thenReturn(Map.of("id", "plink_123", "short_url", "https://rzp.io/i/abc"));

        PaymentLink link = svc.createForInvoice(invoiceId);

        ArgumentCaptor<Long> paise = ArgumentCaptor.forClass(Long.class);
        verify(razorpayClient).createPaymentLink(eq(orgId), paise.capture(), eq("INR"), eq("INV-001"),
                anyString(), any(), any(), any());
        assertThat(paise.getValue()).isEqualTo(50000L);   // 500.00 -> paise
        assertThat(link.getProviderLinkId()).isEqualTo("plink_123");
        assertThat(link.getShortUrl()).isEqualTo("https://rzp.io/i/abc");
        assertThat(link.getStatus()).isEqualTo("CREATED");
        assertThat(link.getReferenceId()).isEqualTo("INV-001");
    }

    @Test
    void createForInvoice_rejects_a_non_payable_invoice() {
        Invoice draft = payableInvoice("500.00");
        draft.setStatus("DRAFT");
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(draft));

        assertThatThrownBy(() -> svc.createForInvoice(invoiceId))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "PAYLINK_INVOICE_NOT_PAYABLE");
        verify(razorpayClient, never()).createPaymentLink(any(), anyLong(), any(), any(), any(), any(), any(), any());
    }

    // ── webhook ──

    private String paidPayload(String plinkId, String payId, long amountPaise) {
        return "{\"event\":\"payment_link.paid\",\"payload\":{"
                + "\"payment_link\":{\"entity\":{\"id\":\"" + plinkId + "\",\"reference_id\":\"INV-001\","
                + "\"amount\":" + amountPaise + ",\"amount_paid\":" + amountPaise + "}},"
                + "\"payment\":{\"entity\":{\"id\":\"" + payId + "\",\"amount\":" + amountPaise + "}}}}";
    }

    private PaymentLink createdLink(String balance) {
        PaymentLink l = PaymentLink.builder()
                .invoiceId(invoiceId).provider("RAZORPAY").providerLinkId("plink_123")
                .referenceId("INV-001").amount(new BigDecimal(balance)).currency("INR").status("CREATED")
                .build();
        l.setId(UUID.randomUUID());
        l.setOrgId(orgId);
        return l;
    }

    @Test
    void webhook_records_payment_and_flips_link_to_paid() {
        String body = paidPayload("plink_123", "pay_abc", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_1")).thenReturn(false);
        when(paymentLinkRepository.findByProviderAndProviderPaymentIdAndIsDeletedFalse("RAZORPAY", "pay_abc"))
                .thenReturn(Optional.empty());
        PaymentLink link = createdLink("500.00");
        when(paymentLinkRepository.findByProviderAndProviderLinkIdAndIsDeletedFalse("RAZORPAY", "plink_123"))
                .thenReturn(Optional.of(link));
        when(paymentLinkRepository.findByIdAndIsDeletedFalse(link.getId())).thenReturn(Optional.of(link));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(payableInvoice("500.00")));
        UUID paymentId = UUID.randomUUID();
        when(paymentService.recordForInvoice(eq(invoiceId), any()))
                .thenReturn(paymentResponse(paymentId, "POSTED"));

        String result = svc.handleWebhook(orgId, body, "sig", "evt_1");

        assertThat(result).isEqualTo("recorded");
        ArgumentCaptor<RecordPaymentForInvoiceRequest> req = ArgumentCaptor.forClass(RecordPaymentForInvoiceRequest.class);
        verify(paymentService).recordForInvoice(eq(invoiceId), req.capture());
        assertThat(req.getValue().amount()).isEqualByComparingTo("500.00");
        assertThat(req.getValue().paymentMethod()).isEqualTo("BANK_TRANSFER"); // routes to BANK, not CASH
        assertThat(link.getStatus()).isEqualTo("PAID");
        assertThat(link.getProviderPaymentId()).isEqualTo("pay_abc");
        assertThat(link.getRecordedPaymentId()).isEqualTo(paymentId);
    }

    @Test
    void webhook_rejects_an_invalid_signature_without_recording() {
        String body = paidPayload("plink_123", "pay_abc", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "bad")).thenReturn(false);

        assertThat(svc.handleWebhook(orgId, body, "bad", "evt_1")).isEqualTo("invalid signature");
        verify(paymentService, never()).recordForInvoice(any(), any());
        verify(webhookEventRepository, never()).save(any());
    }

    @Test
    void webhook_dedupes_a_duplicate_event_id() {
        String body = paidPayload("plink_123", "pay_abc", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_1")).thenReturn(true);

        assertThat(svc.handleWebhook(orgId, body, "sig", "evt_1")).isEqualTo("duplicate event");
        verify(paymentService, never()).recordForInvoice(any(), any());
    }

    @Test
    void webhook_no_ops_when_captured_payment_already_recorded() {
        String body = paidPayload("plink_123", "pay_abc", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_2")).thenReturn(false);
        when(paymentLinkRepository.findByProviderAndProviderPaymentIdAndIsDeletedFalse("RAZORPAY", "pay_abc"))
                .thenReturn(Optional.of(createdLink("500.00"))); // already carries this pay id

        assertThat(svc.handleWebhook(orgId, body, "sig", "evt_2")).isEqualTo("already recorded");
        verify(paymentService, never()).recordForInvoice(any(), any());
    }

    @Test
    void webhook_clamps_amount_to_current_balance() {
        String body = paidPayload("plink_123", "pay_abc", 100000); // ₹1000 captured
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_3")).thenReturn(false);
        when(paymentLinkRepository.findByProviderAndProviderPaymentIdAndIsDeletedFalse("RAZORPAY", "pay_abc"))
                .thenReturn(Optional.empty());
        PaymentLink clampLink = createdLink("1000.00");
        when(paymentLinkRepository.findByProviderAndProviderLinkIdAndIsDeletedFalse("RAZORPAY", "plink_123"))
                .thenReturn(Optional.of(clampLink));
        when(paymentLinkRepository.findByIdAndIsDeletedFalse(clampLink.getId())).thenReturn(Optional.of(clampLink));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(payableInvoice("300.00"))); // only ₹300 still owed
        when(paymentService.recordForInvoice(eq(invoiceId), any()))
                .thenReturn(paymentResponse(UUID.randomUUID(), "POSTED"));

        svc.handleWebhook(orgId, body, "sig", "evt_3");

        ArgumentCaptor<RecordPaymentForInvoiceRequest> req = ArgumentCaptor.forClass(RecordPaymentForInvoiceRequest.class);
        verify(paymentService).recordForInvoice(eq(invoiceId), req.capture());
        assertThat(req.getValue().amount()).isEqualByComparingTo("300.00"); // clamped
    }

    @Test
    void webhook_force_posts_a_pending_approval_payment() {
        String body = paidPayload("plink_123", "pay_abc", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_4")).thenReturn(false);
        when(paymentLinkRepository.findByProviderAndProviderPaymentIdAndIsDeletedFalse("RAZORPAY", "pay_abc"))
                .thenReturn(Optional.empty());
        PaymentLink fpLink = createdLink("500.00");
        when(paymentLinkRepository.findByProviderAndProviderLinkIdAndIsDeletedFalse("RAZORPAY", "plink_123"))
                .thenReturn(Optional.of(fpLink));
        when(paymentLinkRepository.findByIdAndIsDeletedFalse(fpLink.getId())).thenReturn(Optional.of(fpLink));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(payableInvoice("500.00")));
        UUID paymentId = UUID.randomUUID();
        when(paymentService.recordForInvoice(eq(invoiceId), any()))
                .thenReturn(paymentResponse(paymentId, "PENDING_APPROVAL"));

        svc.handleWebhook(orgId, body, "sig", "evt_4");

        // money already collected → force settle past the approval gate
        verify(paymentService).postPayment(paymentId);
    }

    @Test
    void webhook_propagates_a_transient_error_so_the_endpoint_can_retry() {
        String body = paidPayload("plink_123", "pay_abc", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_5")).thenReturn(false);
        when(paymentLinkRepository.findByProviderAndProviderPaymentIdAndIsDeletedFalse("RAZORPAY", "pay_abc"))
                .thenReturn(Optional.empty());
        PaymentLink link = createdLink("500.00");
        when(paymentLinkRepository.findByProviderAndProviderLinkIdAndIsDeletedFalse("RAZORPAY", "plink_123"))
                .thenReturn(Optional.of(link));
        when(paymentLinkRepository.findByIdAndIsDeletedFalse(link.getId())).thenReturn(Optional.of(link));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(payableInvoice("500.00")));
        // a transient infra error (deadlock/lock-timeout) — NOT a BusinessException
        when(paymentService.recordForInvoice(eq(invoiceId), any()))
                .thenThrow(new org.springframework.dao.PessimisticLockingFailureException("deadlock"));

        // must propagate so the controller returns 5xx and Razorpay retries;
        // the dedupe row must NOT be persisted (whole txn rolls back)
        assertThatThrownBy(() -> svc.handleWebhook(orgId, body, "sig", "evt_5"))
                .isInstanceOf(org.springframework.dao.PessimisticLockingFailureException.class);
        verify(webhookEventRepository, never()).save(any());
    }

    private PaymentResponse paymentResponse(UUID id, String status) {
        return new PaymentResponse(id, UUID.randomUUID(), null, invoiceId, "INV-001",
                "PAY-1", LocalDate.now(), new BigDecimal("500.00"), "INR", "BANK_TRANSFER",
                null, null, null, status, null, null, null);
    }

    @Test
    void webhook_supplies_the_link_creator_as_the_actor_on_the_system_thread() {
        // The webhook runs on a SYSTEM thread with no acting user, but the
        // settlement journal needs a non-null created_by. The link's creator must
        // be stamped onto TenantContext before recordForInvoice posts the journal.
        TenantContext.setCurrentUserId(null);
        UUID creator = UUID.randomUUID();
        String body = paidPayload("plink_123", "pay_actor", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_actor")).thenReturn(false);
        when(paymentLinkRepository.findByProviderAndProviderPaymentIdAndIsDeletedFalse("RAZORPAY", "pay_actor"))
                .thenReturn(Optional.empty());
        PaymentLink link = createdLink("500.00");
        link.setCreatedBy(creator);
        when(paymentLinkRepository.findByProviderAndProviderLinkIdAndIsDeletedFalse("RAZORPAY", "plink_123"))
                .thenReturn(Optional.of(link));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(payableInvoice("500.00")));
        UUID[] actorAtRecord = new UUID[1];
        when(paymentService.recordForInvoice(eq(invoiceId), any())).thenAnswer(inv -> {
            actorAtRecord[0] = TenantContext.getCurrentUserId();
            return paymentResponse(UUID.randomUUID(), "POSTED");
        });

        assertThat(svc.handleWebhook(orgId, body, "sig", "evt_actor")).isEqualTo("recorded");
        assertThat(actorAtRecord[0]).isEqualTo(creator);
    }

    @Test
    void webhook_flags_an_unattributed_capture_when_the_invoice_is_already_settled() {
        String body = paidPayload("plink_123", "pay_unattr", 50000);
        when(razorpayClient.verifyWebhookSignature(orgId, body, "sig")).thenReturn(true);
        when(webhookEventRepository.existsByProviderAndEventId("RAZORPAY", "evt_unattr")).thenReturn(false);
        when(paymentLinkRepository.findByProviderAndProviderPaymentIdAndIsDeletedFalse("RAZORPAY", "pay_unattr"))
                .thenReturn(Optional.empty());
        PaymentLink link = createdLink("500.00");
        when(paymentLinkRepository.findByProviderAndProviderLinkIdAndIsDeletedFalse("RAZORPAY", "plink_123"))
                .thenReturn(Optional.of(link));
        Invoice paid = payableInvoice("500.00");
        paid.setStatus("PAID"); // already settled by a manual receipt
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(paid));
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any()))
                .thenReturn(false);

        String result = svc.handleWebhook(orgId, body, "sig", "evt_unattr");

        assertThat(result).isEqualTo("unapplied capture flagged");
        verify(aiSuggestionService).createSuggestion(any());
        verify(paymentService, never()).recordForInvoice(any(), any());
        assertThat(link.getStatus()).isEqualTo("PAID");
        assertThat(link.getProviderPaymentId()).isEqualTo("pay_unattr");
        assertThat(link.getRecordedPaymentId()).isNull();
    }
}
