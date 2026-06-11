package com.katasticho.erp.tax.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.tax.service.TcsService.TcsComputation;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class TcsServiceTest {

    private final InvoiceRepository invoiceRepository = mock(InvoiceRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);

    private final TcsService service = new TcsService(
            invoiceRepository, contactRepository, orgSettingsService);

    private final UUID orgId = UUID.randomUUID();
    private final UUID buyerId = UUID.randomUUID();
    private final LocalDate date = LocalDate.of(2026, 6, 10);   // FY 2026-27

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(orgSettingsService.get(orgId, TcsService.SETTING_ENABLED, "false")).thenReturn("true");
        when(orgSettingsService.get(orgId, TcsService.SETTING_RATE, "0.1")).thenReturn("0.1");
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private void aggregateBefore(String amount) {
        when(invoiceRepository.sumPostedConsiderationByOrgAndContactAndDateRange(
                eq(orgId), eq(buyerId), eq(LocalDate.of(2026, 4, 1)), eq(LocalDate.of(2027, 3, 31))))
                .thenReturn(new BigDecimal(amount));
    }

    @Test
    void belowThresholdCollectsNothing() {
        aggregateBefore("1000000");   // 10L before + 5L this = 15L, under 50L
        assertThat(service.computeForInvoice(orgId, buyerId, new BigDecimal("500000"), date)).isNull();
    }

    @Test
    void crossingThresholdCollectsOnExcessOnly() {
        aggregateBefore("4900000");   // 49L before + 5L this = 54L → excess 4L
        TcsComputation tcs = service.computeForInvoice(orgId, buyerId, new BigDecimal("500000"), date);

        assertThat(tcs).isNotNull();
        assertThat(tcs.baseAmount()).isEqualByComparingTo("400000");   // only the slice above 50L
        assertThat(tcs.amount()).isEqualByComparingTo("400");          // 0.1% of 4L
        assertThat(tcs.note()).contains("206C(1H)");
    }

    @Test
    void fullyAboveThresholdCollectsOnWholeInvoice() {
        aggregateBefore("6000000");   // already past 50L → whole invoice is excess
        TcsComputation tcs = service.computeForInvoice(orgId, buyerId, new BigDecimal("200000"), date);

        assertThat(tcs.baseAmount()).isEqualByComparingTo("200000");
        assertThat(tcs.amount()).isEqualByComparingTo("200");
    }

    @Test
    void disabledSettingCollectsNothing() {
        when(orgSettingsService.get(orgId, TcsService.SETTING_ENABLED, "false")).thenReturn("false");
        aggregateBefore("9000000");
        assertThat(service.computeForInvoice(orgId, buyerId, new BigDecimal("500000"), date)).isNull();
    }

    @Test
    void customRateApplies() {
        when(orgSettingsService.get(orgId, TcsService.SETTING_RATE, "0.1")).thenReturn("1");
        aggregateBefore("6000000");
        TcsComputation tcs = service.computeForInvoice(orgId, buyerId, new BigDecimal("100000"), date);
        assertThat(tcs.amount()).isEqualByComparingTo("1000");   // 1% of 1L
    }

    @Test
    void fyBoundaryUsesAprilToMarch() {
        // March 2026 belongs to FY 2025-26, not 2026-27.
        LocalDate march = LocalDate.of(2026, 3, 15);
        when(invoiceRepository.sumPostedConsiderationByOrgAndContactAndDateRange(
                eq(orgId), eq(buyerId), eq(LocalDate.of(2025, 4, 1)), eq(LocalDate.of(2026, 3, 31))))
                .thenReturn(new BigDecimal("6000000"));

        TcsComputation tcs = service.computeForInvoice(orgId, buyerId, new BigDecimal("100000"), march);
        assertThat(tcs).isNotNull();
        assertThat(tcs.amount()).isEqualByComparingTo("100");
    }

    @Test
    void form27eqGroupsByBuyer() {
        Contact buyer = Contact.builder()
                .contactType(ContactType.CUSTOMER).displayName("Mega Distributors").pan("AAAPM1234A").build();
        buyer.setId(buyerId);

        Invoice i1 = Invoice.builder().contactId(buyerId).invoiceNumber("INV-1")
                .invoiceDate(LocalDate.of(2026, 4, 20))
                .totalAmount(new BigDecimal("1000400")).tcsAmount(new BigDecimal("400")).build();
        Invoice i2 = Invoice.builder().contactId(buyerId).invoiceNumber("INV-2")
                .invoiceDate(LocalDate.of(2026, 5, 5))
                .totalAmount(new BigDecimal("500200")).tcsAmount(new BigDecimal("200")).build();
        Invoice noTcs = Invoice.builder().contactId(UUID.randomUUID()).invoiceNumber("INV-3")
                .invoiceDate(LocalDate.of(2026, 5, 6))
                .totalAmount(new BigDecimal("1000")).tcsAmount(BigDecimal.ZERO).build();

        when(invoiceRepository.findPostedByOrgAndDateRange(
                eq(orgId), eq(LocalDate.of(2026, 4, 1)), eq(LocalDate.of(2026, 6, 30))))
                .thenReturn(List.of(i1, i2, noTcs));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(buyer));

        Map<String, Object> result = service.form27eq(2026, 1);

        assertThat(result.get("quarter")).isEqualTo("Q1");
        assertThat(result.get("collecteeCount")).isEqualTo(1);   // no-TCS invoice excluded
        assertThat((BigDecimal) result.get("totalTcsCollected")).isEqualByComparingTo("600");
        // Consideration excludes the TCS itself
        assertThat((BigDecimal) result.get("totalAmountReceived")).isEqualByComparingTo("1500000");
        @SuppressWarnings("unchecked")
        var collectees = (List<Map<String, Object>>) result.get("collectees");
        assertThat(collectees.get(0).get("collecteePan")).isEqualTo("AAAPM1234A");
        assertThat(collectees.get(0).get("invoiceCount")).isEqualTo(2);
    }

    @Test
    void registerListsOnlyTcsInvoices() {
        Invoice withTcs = Invoice.builder().contactId(buyerId).invoiceNumber("INV-9")
                .invoiceDate(LocalDate.of(2026, 6, 1))
                .totalAmount(new BigDecimal("200200")).tcsAmount(new BigDecimal("200")).build();
        Invoice without = Invoice.builder().contactId(buyerId).invoiceNumber("INV-10")
                .invoiceDate(LocalDate.of(2026, 6, 2))
                .totalAmount(new BigDecimal("5000")).tcsAmount(BigDecimal.ZERO).build();
        when(invoiceRepository.findPostedByOrgAndDateRange(any(), any(), any()))
                .thenReturn(List.of(withTcs, without));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(any(), any()))
                .thenReturn(List.of());

        var rows = service.register(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30));

        assertThat(rows).hasSize(1);
        assertThat(rows.get(0).get("invoiceNumber")).isEqualTo("INV-9");
        assertThat((BigDecimal) rows.get(0).get("consideration")).isEqualByComparingTo("200000");
    }
}
