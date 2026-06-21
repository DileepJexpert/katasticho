package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DistributionAnomalyDetectorTest {

    @Mock private VendorPaymentRepository vendorPaymentRepository;
    @Mock private AiSuggestionRepository aiSuggestionRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private InvoiceRepository invoiceRepository;

    private DistributionAnomalyDetector detector;
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        detector = new DistributionAnomalyDetector(
                vendorPaymentRepository, aiSuggestionRepository,
                itemRepository, contactRepository, invoiceRepository,
                new ObjectMapper());
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    // ── Duplicate vendor payments ────────────────────────────────

    @Test
    void duplicates_raise_one_suggestion_per_group() {
        UUID vendor = UUID.randomUUID();
        VendorPayment a = payment(vendor, "5000");
        VendorPayment b = payment(vendor, "5000");
        when(vendorPaymentRepository
                .findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
                        eq(orgId), any(), any(), any())).thenReturn(pageOf(a, b));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), anyString(), any(), any(), anyString(), anyCollection()))
                .thenReturn(false);

        int raised = detector.scanDuplicateVendorPayments(7);
        assertEquals(1, raised);

        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(cap.capture());
        var s = cap.getValue();
        assertEquals("DUPLICATE_PAYMENT", s.getSuggestionType());
        assertEquals("HIGH", s.getPriority());
        assertEquals("VENDOR_PAYMENT", s.getEntityType());
    }

    @Test
    void single_payment_in_group_does_not_raise() {
        when(vendorPaymentRepository
                .findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
                        eq(orgId), any(), any(), any()))
                .thenReturn(pageOf(payment(UUID.randomUUID(), "5000")));

        int raised = detector.scanDuplicateVendorPayments(7);
        assertEquals(0, raised);
        verify(aiSuggestionRepository, never()).save(any());
    }

    @Test
    void duplicates_with_existing_suggestion_are_skipped_no_double_inbox() {
        UUID vendor = UUID.randomUUID();
        VendorPayment a = payment(vendor, "5000");
        VendorPayment b = payment(vendor, "5000");
        when(vendorPaymentRepository
                .findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
                        eq(orgId), any(), any(), any())).thenReturn(pageOf(a, b));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), anyString(), any(), any(), anyString(), anyCollection()))
                .thenReturn(true); // already raised previously

        int raised = detector.scanDuplicateVendorPayments(7);
        assertEquals(0, raised);
        verify(aiSuggestionRepository, never()).save(any());
    }

    @Test
    void different_vendors_same_amount_are_not_flagged() {
        VendorPayment a = payment(UUID.randomUUID(), "5000");
        VendorPayment b = payment(UUID.randomUUID(), "5000");
        when(vendorPaymentRepository
                .findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
                        eq(orgId), any(), any(), any())).thenReturn(pageOf(a, b));

        int raised = detector.scanDuplicateVendorPayments(7);
        assertEquals(0, raised);
    }

    // ── Margin erosion ───────────────────────────────────────────

    @Test
    void selling_below_cost_raises_HIGH_priority_suggestion() {
        Item item = makeItem("Surf Excel", "100", "120"); // sale 100, cost 120 → loss
        when(itemRepository.findByOrgIdAndIsDeletedFalse(eq(orgId), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(item)));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), anyString(), any(), any(), anyString(), anyCollection()))
                .thenReturn(false);

        int raised = detector.scanMarginErosion(BigDecimal.ZERO);
        assertEquals(1, raised);

        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(cap.capture());
        var s = cap.getValue();
        assertEquals("MARGIN_EROSION", s.getSuggestionType());
        assertEquals("HIGH", s.getPriority());
    }

    @Test
    void selling_above_cost_at_threshold_does_not_raise() {
        Item ok = makeItem("Tide", "120", "100"); // 20% margin
        when(itemRepository.findByOrgIdAndIsDeletedFalse(eq(orgId), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(ok)));

        int raised = detector.scanMarginErosion(new BigDecimal("0.10")); // ≥10% required
        assertEquals(0, raised);
        verify(aiSuggestionRepository, never()).save(any());
    }

    @Test
    void thin_margin_below_threshold_raises_MEDIUM_when_not_loss() {
        Item thin = makeItem("Ariel", "102", "100"); // 2% margin, not a loss
        when(itemRepository.findByOrgIdAndIsDeletedFalse(eq(orgId), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(thin)));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), anyString(), any(), any(), anyString(), anyCollection()))
                .thenReturn(false);

        int raised = detector.scanMarginErosion(new BigDecimal("0.05"));
        assertEquals(1, raised);
        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(cap.capture());
        assertEquals("MEDIUM", cap.getValue().getPriority(),
                "thin but not loss should be MEDIUM not HIGH");
    }

    @Test
    void items_without_cost_or_sale_price_are_skipped() {
        Item noCost = makeItem("Loose", "100", null);
        Item noSale = makeItem("Loose2", null, "100");
        Item zeroCost = makeItem("Free", "10", "0");
        when(itemRepository.findByOrgIdAndIsDeletedFalse(eq(orgId), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(noCost, noSale, zeroCost)));

        int raised = detector.scanMarginErosion(BigDecimal.ZERO);
        assertEquals(0, raised);
    }

    // ── Credit-limit breaches ────────────────────────────────────

    @Test
    void credit_limit_breach_raises_freeze_credit_suggestion() {
        Contact c = customer("Shri Balaji", "100000");
        when(contactRepository.findByOrgIdAndContactTypeAndIsDeletedFalse(
                eq(orgId), eq(ContactType.CUSTOMER), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(c)));
        when(invoiceRepository.findOutstandingByContact(orgId, c.getId()))
                .thenReturn(List.of(invoice("125000"), invoice("30000")));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), anyString(), any(), any(), anyString(), anyCollection()))
                .thenReturn(false);

        int raised = detector.scanCreditLimitBreaches();
        assertEquals(1, raised);
        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(cap.capture());
        assertEquals("CREDIT_LIMIT_BREACH", cap.getValue().getSuggestionType());
        assertEquals("FREEZE_CREDIT", cap.getValue().getSuggestedAction());
        assertEquals("HIGH", cap.getValue().getPriority());
    }

    @Test
    void within_credit_limit_is_silent() {
        Contact c = customer("Calm Customer", "100000");
        when(contactRepository.findByOrgIdAndContactTypeAndIsDeletedFalse(
                eq(orgId), eq(ContactType.CUSTOMER), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(c)));
        when(invoiceRepository.findOutstandingByContact(orgId, c.getId()))
                .thenReturn(List.of(invoice("50000")));

        int raised = detector.scanCreditLimitBreaches();
        assertEquals(0, raised);
        verify(aiSuggestionRepository, never()).save(any());
    }

    @Test
    void zero_or_null_credit_limit_means_unlimited_skipped() {
        Contact unlimited = customer("Premium", null);
        Contact zero = customer("Loose", "0");
        when(contactRepository.findByOrgIdAndContactTypeAndIsDeletedFalse(
                eq(orgId), eq(ContactType.CUSTOMER), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(unlimited, zero)));

        int raised = detector.scanCreditLimitBreaches();
        assertEquals(0, raised);
    }

    @Test
    void runAll_dispatches_to_all_three_detectors() {
        when(vendorPaymentRepository
                .findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
                        eq(orgId), any(), any(), any())).thenReturn(new PageImpl<>(List.of()));
        when(itemRepository.findByOrgIdAndIsDeletedFalse(eq(orgId), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));
        when(contactRepository.findByOrgIdAndContactTypeAndIsDeletedFalse(
                eq(orgId), eq(ContactType.CUSTOMER), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        var out = detector.runAll();
        assertTrue(out.containsKey("duplicateVendorPayments"));
        assertTrue(out.containsKey("marginErosion"));
        assertTrue(out.containsKey("creditLimitBreaches"));
    }

    // ── helpers ──────────────────────────────────────────────────

    private VendorPayment payment(UUID contactId, String amount) {
        VendorPayment p = new VendorPayment();
        p.setId(UUID.randomUUID());
        p.setOrgId(orgId);
        p.setContactId(contactId);
        p.setAmount(new BigDecimal(amount));
        p.setPaymentDate(LocalDate.now());
        return p;
    }

    private Page<VendorPayment> pageOf(VendorPayment... ps) {
        return new PageImpl<>(List.of(ps));
    }

    private Item makeItem(String name, String sale, String cost) {
        Item i = new Item();
        i.setId(UUID.randomUUID());
        i.setOrgId(orgId);
        i.setName(name);
        i.setSalePrice(sale == null ? null : new BigDecimal(sale));
        i.setPurchasePrice(cost == null ? null : new BigDecimal(cost));
        return i;
    }

    private Contact customer(String name, String creditLimit) {
        Contact c = new Contact();
        c.setId(UUID.randomUUID());
        c.setOrgId(orgId);
        c.setDisplayName(name);
        c.setContactType(ContactType.CUSTOMER);
        c.setCreditLimit(creditLimit == null ? null : new BigDecimal(creditLimit));
        return c;
    }

    private Invoice invoice(String balanceDue) {
        Invoice i = new Invoice();
        i.setBalanceDue(new BigDecimal(balanceDue));
        return i;
    }
}
