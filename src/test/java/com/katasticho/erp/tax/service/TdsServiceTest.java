package com.katasticho.erp.tax.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class TdsServiceTest {

    private final PurchaseBillRepository purchaseBillRepository = mock(PurchaseBillRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final TdsService service = new TdsService(purchaseBillRepository, contactRepository);

    private final UUID orgId = UUID.randomUUID();
    private final UUID vendorId = UUID.randomUUID();

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Contact vendor(String section, String rate) {
        Contact c = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName("BuildWell Contractors")
                .pan("AAAPB1234C")
                .tdsApplicable(true)
                .tdsSection(section)
                .tdsRate(rate == null ? null : new BigDecimal(rate))
                .build();
        c.setId(vendorId);
        return c;
    }

    private void fyAggregate(String amount) {
        when(purchaseBillRepository.sumPostedSubtotalByOrgAndContactAndDateRange(
                eq(orgId), eq(vendorId), any(), any()))
                .thenReturn(new BigDecimal(amount));
    }

    @Test
    void notApplicableVendorGetsNoTds() {
        Contact c = vendor("194C", "2");
        c.setTdsApplicable(false);
        assertThat(service.computeForBill(orgId, c, new BigDecimal("100000"),
                LocalDate.of(2026, 6, 10))).isNull();
    }

    @Test
    void singleBillAbove30kTriggers194c() {
        fyAggregate("0");
        var tds = service.computeForBill(orgId, vendor("194C", "2"),
                new BigDecimal("45000"), LocalDate.of(2026, 6, 10));

        assertThat(tds).isNotNull();
        assertThat(tds.section()).isEqualTo("194C");
        assertThat(tds.amount()).isEqualByComparingTo("900.00"); // 2% of 45,000
    }

    @Test
    void smallBillBelowThresholdsGetsNoTds() {
        fyAggregate("50000"); // aggregate stays under 1L even with this bill
        assertThat(service.computeForBill(orgId, vendor("194C", "2"),
                new BigDecimal("20000"), LocalDate.of(2026, 6, 10))).isNull();
    }

    @Test
    void fyAggregateCrossing1LakhTriggers194c() {
        fyAggregate("95000"); // 95k + 20k = 1.15L > 1L
        var tds = service.computeForBill(orgId, vendor("194C", "2"),
                new BigDecimal("20000"), LocalDate.of(2026, 6, 10));

        assertThat(tds).isNotNull();
        assertThat(tds.amount()).isEqualByComparingTo("400.00"); // 2% of the bill
        assertThat(tds.note()).contains("aggregate");
    }

    @Test
    void section194qDeductsOnlyOnExcessAbove50Lakh() {
        fyAggregate("4950000"); // 49.5L before; 2L bill → 1.5L above the 50L line
        var tds = service.computeForBill(orgId, vendor("194Q", "0.1"),
                new BigDecimal("200000"), LocalDate.of(2026, 6, 10));

        assertThat(tds).isNotNull();
        assertThat(tds.baseAmount()).isEqualByComparingTo("150000");
        assertThat(tds.amount()).isEqualByComparingTo("150.00"); // 0.1% of 1.5L
    }

    @Test
    void missingRateSkipsDeduction() {
        assertThat(service.computeForBill(orgId, vendor("194C", null),
                new BigDecimal("100000"), LocalDate.of(2026, 6, 10))).isNull();
    }

    @Test
    void fiscalYearRunsAprilToMarch() {
        var fy = TdsService.fiscalYearOf(LocalDate.of(2026, 2, 15));
        assertThat(fy.from()).isEqualTo(LocalDate.of(2025, 4, 1));
        assertThat(fy.to()).isEqualTo(LocalDate.of(2026, 3, 31));

        var fy2 = TdsService.fiscalYearOf(LocalDate.of(2026, 4, 1));
        assertThat(fy2.from()).isEqualTo(LocalDate.of(2026, 4, 1));
    }

    @Test
    void form26qGroupsByDeducteeAndSection() {
        TenantContext.setCurrentOrgId(orgId);
        PurchaseBill withTds = PurchaseBill.builder()
                .id(UUID.randomUUID()).contactId(vendorId)
                .billNumber("BILL-1").vendorBillNumber("V-1")
                .billDate(LocalDate.of(2026, 5, 5))
                .subtotal(new BigDecimal("45000")).tdsAmount(new BigDecimal("900"))
                .tdsSection("194C").status("OPEN").build();
        PurchaseBill withTds2 = PurchaseBill.builder()
                .id(UUID.randomUUID()).contactId(vendorId)
                .billNumber("BILL-2").vendorBillNumber("V-2")
                .billDate(LocalDate.of(2026, 6, 1))
                .subtotal(new BigDecimal("35000")).tdsAmount(new BigDecimal("700"))
                .tdsSection("194C").status("OPEN").build();
        PurchaseBill noTds = PurchaseBill.builder()
                .id(UUID.randomUUID()).contactId(vendorId)
                .billNumber("BILL-3").billDate(LocalDate.of(2026, 6, 2))
                .subtotal(new BigDecimal("10000")).tdsAmount(BigDecimal.ZERO)
                .status("OPEN").build();
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(withTds, withTds2, noTds));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor("194C", "2")));

        Map<String, Object> q1 = service.form26q(2026, 1);

        assertThat(q1.get("quarter")).isEqualTo("Q1");
        assertThat(q1.get("deducteeCount")).isEqualTo(1);
        assertThat((BigDecimal) q1.get("totalTdsDeducted")).isEqualByComparingTo("1600");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> deductees = (List<Map<String, Object>>) q1.get("deductees");
        assertThat(deductees).hasSize(1);
        assertThat(deductees.get(0).get("deducteePan")).isEqualTo("AAAPB1234C");
        assertThat(deductees.get(0).get("billCount")).isEqualTo(2);
        assertThat(q1.get("missingPanCount")).isEqualTo(0);
    }
}
