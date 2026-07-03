package com.katasticho.erp.reporting.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.entity.VendorPaymentAllocation;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentAllocationRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MsmeForm1ServiceTest {

    @Mock
    private ContactRepository contactRepository;
    @Mock
    private PurchaseBillRepository purchaseBillRepository;
    @Mock
    private VendorPaymentAllocationRepository allocationRepository;

    private MsmeForm1Service service;

    private final UUID orgId = UUID.randomUUID();
    // Fixed "today" = 2026-07-02 → half-year Apr 1 – Sep 30 2026
    private final LocalDate today = LocalDate.of(2026, 7, 2);

    @BeforeEach
    void setUp() {
        Clock fixed = Clock.fixed(Instant.parse("2026-07-02T06:00:00Z"), ZoneOffset.UTC);
        service = new MsmeForm1Service(contactRepository, purchaseBillRepository,
                allocationRepository, fixed);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Contact vendor(String name, String pan) {
        Contact vendor = Contact.builder()
                .displayName(name)
                .contactType(ContactType.VENDOR)
                .pan(pan)
                .msmeRegistered(true)
                .msmeRegistrationNo("UDYAM-MH-00-0000001")
                .build();
        vendor.setId(UUID.randomUUID());
        vendor.setOrgId(orgId);
        return vendor;
    }

    private PurchaseBill bill(Contact vendor, String number, LocalDate billDate,
                              LocalDate dueDate, String balanceDue) {
        return PurchaseBill.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .contactId(vendor.getId())
                .billNumber(number)
                .billDate(billDate)
                .dueDate(dueDate)
                .status("OPEN")
                .totalAmount(new BigDecimal(balanceDue))
                .balanceDue(new BigDecimal(balanceDue))
                .build();
    }

    private VendorPaymentAllocation allocation(PurchaseBill bill, LocalDate paymentDate,
                                               String amount) {
        VendorPayment payment = VendorPayment.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .contactId(bill.getContactId())
                .paymentNumber("VP-1")
                .paymentDate(paymentDate)
                .amount(new BigDecimal(amount))
                .build();
        return VendorPaymentAllocation.builder()
                .id(UUID.randomUUID())
                .vendorPayment(payment)
                .purchaseBillId(bill.getId())
                .amountApplied(new BigDecimal(amount))
                .build();
    }

    @Test
    void outstandingBucketsSplitAtThe45DayLimit() {
        Contact vendor = vendor("Micro Springs Pvt Ltd", "AAACM1234F");
        // 80 days old → 35 days beyond the 45-day limit; 30 days old → within
        PurchaseBill overdue = bill(vendor, "PB-1", today.minusDays(80), null, "10000");
        PurchaseBill recent = bill(vendor, "PB-2", today.minusDays(30), null, "5000");
        when(contactRepository.findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse(orgId))
                .thenReturn(List.of(vendor));
        when(purchaseBillRepository.findByOrgIdAndContactIdInAndIsDeletedFalse(eq(orgId), anyCollection()))
                .thenReturn(List.of(overdue, recent));
        when(allocationRepository.findByPurchaseBillIdIn(anyCollection())).thenReturn(List.of());

        Map<String, Object> report = service.report(null, null, null);

        List<Map<String, Object>> rows = rows(report.get("outstandingRows"));
        assertThat(rows).hasSize(2);
        // worst first
        assertThat(rows.get(0).get("billNumber")).isEqualTo("PB-1");
        assertThat(rows.get(0).get("daysOverdue")).isEqualTo(35L);
        assertThat(rows.get(0).get("beyond45")).isEqualTo(true);
        assertThat(rows.get(1).get("daysOverdue")).isEqualTo(0L);
        Map<String, Object> totals = map(report.get("totals"));
        assertThat(totals.get("outstandingOver45")).isEqualTo(new BigDecimal("10000"));
        assertThat(totals.get("outstandingWithin45")).isEqualTo(new BigDecimal("5000"));
        // supplier PAN surfaces on the row (the annexure column)
        assertThat(rows.get(0).get("pan")).isEqualTo("AAACM1234F");
    }

    @Test
    void agreedDueDateBindsWhenShorterButIsCappedAt45Days() {
        LocalDate billDate = LocalDate.of(2026, 5, 1);
        PurchaseBill shortTerms = PurchaseBill.builder()
                .billDate(billDate).dueDate(billDate.plusDays(20)).build();
        PurchaseBill longTerms = PurchaseBill.builder()
                .billDate(billDate).dueDate(billDate.plusDays(90)).build();
        PurchaseBill noTerms = PurchaseBill.builder().billDate(billDate).build();

        assertThat(MsmeForm1Service.msmeDeadline(shortTerms)).isEqualTo(billDate.plusDays(20));
        assertThat(MsmeForm1Service.msmeDeadline(longTerms)).isEqualTo(billDate.plusDays(45));
        assertThat(MsmeForm1Service.msmeDeadline(noTerms)).isEqualTo(billDate.plusDays(45));
    }

    @Test
    void paymentsClassifiedByPaymentDateAgainstTheDeadline_andPeriodFiltered() {
        Contact vendor = vendor("Micro Springs Pvt Ltd", "AAACM1234F");
        PurchaseBill paid = bill(vendor, "PB-3", LocalDate.of(2026, 4, 10), null, "0");
        when(contactRepository.findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse(orgId))
                .thenReturn(List.of(vendor));
        when(purchaseBillRepository.findByOrgIdAndContactIdInAndIsDeletedFalse(eq(orgId), anyCollection()))
                .thenReturn(List.of(paid));
        // deadline = Apr 10 + 45d = May 25. Paid Jun 10 → 16 days late.
        // Second allocation paid within. Third falls outside the half-year → dropped.
        when(allocationRepository.findByPurchaseBillIdIn(anyCollection())).thenReturn(List.of(
                allocation(paid, LocalDate.of(2026, 6, 10), "7000"),
                allocation(paid, LocalDate.of(2026, 4, 20), "3000"),
                allocation(paid, LocalDate.of(2026, 2, 1), "999")));

        Map<String, Object> report = service.report(null, null, null);

        List<Map<String, Object>> rows = rows(report.get("paidRows"));
        assertThat(rows).hasSize(2);
        assertThat(rows.get(0).get("daysOverdue")).isEqualTo(16L);
        assertThat(rows.get(0).get("paymentDate")).isEqualTo(LocalDate.of(2026, 6, 10));
        Map<String, Object> totals = map(report.get("totals"));
        assertThat(totals.get("paidBeyond45")).isEqualTo(new BigDecimal("7000"));
        assertThat(totals.get("paidWithin45")).isEqualTo(new BigDecimal("3000"));
    }

    @Test
    void draftAndVoidBillsAreExcluded_noMsmeVendorsShortCircuits() {
        Contact vendor = vendor("Micro Springs Pvt Ltd", "AAACM1234F");
        PurchaseBill draft = bill(vendor, "PB-D", today.minusDays(90), null, "1000");
        draft.setStatus("DRAFT");
        PurchaseBill voided = bill(vendor, "PB-V", today.minusDays(90), null, "2000");
        voided.setStatus("VOID");
        when(contactRepository.findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse(orgId))
                .thenReturn(List.of(vendor));
        when(purchaseBillRepository.findByOrgIdAndContactIdInAndIsDeletedFalse(eq(orgId), anyCollection()))
                .thenReturn(List.of(draft, voided));

        Map<String, Object> report = service.report(null, null, null);
        assertThat(rows(report.get("outstandingRows"))).isEmpty();

        // and: no MSME vendors → bill repo never queried
        when(contactRepository.findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse(orgId))
                .thenReturn(List.of());
        Map<String, Object> empty = service.report(null, null, null);
        assertThat(empty.get("msmeVendorCount")).isEqualTo(0);
        assertThat(empty.get("note")).asString().contains("MSME");
        verify(purchaseBillRepository, never())
                .findByOrgIdAndContactIdInAndIsDeletedFalse(eq(orgId), eq(List.of()));
    }

    @Test
    void csvExportCarriesSectionsAndEscapesCommas() {
        Contact vendor = vendor("Springs, Micro & Co", "AAACM1234F");
        PurchaseBill overdue = bill(vendor, "PB-1", today.minusDays(80), null, "10000");
        when(contactRepository.findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse(orgId))
                .thenReturn(List.of(vendor));
        when(purchaseBillRepository.findByOrgIdAndContactIdInAndIsDeletedFalse(eq(orgId), anyCollection()))
                .thenReturn(List.of(overdue));
        when(allocationRepository.findByPurchaseBillIdIn(anyCollection())).thenReturn(List.of());

        String csv = new String(service.exportCsv(null, null, null), StandardCharsets.UTF_8);

        assertThat(csv).startsWith("Section,Supplier,PAN,MSME Reg No,");
        assertThat(csv).contains("OUTSTANDING_OVER_45");
        assertThat(csv).contains("\"Springs, Micro & Co\"");
        assertThat(csv).contains("AAACM1234F");
    }

    @Test
    void halfYearBucketsFollowTheMcaCycle() {
        assertThat(MsmeForm1Service.halfYearOf(LocalDate.of(2026, 7, 2)))
                .containsExactly(LocalDate.of(2026, 4, 1), LocalDate.of(2026, 9, 30));
        assertThat(MsmeForm1Service.halfYearOf(LocalDate.of(2026, 11, 15)))
                .containsExactly(LocalDate.of(2026, 10, 1), LocalDate.of(2027, 3, 31));
        assertThat(MsmeForm1Service.halfYearOf(LocalDate.of(2026, 2, 10)))
                .containsExactly(LocalDate.of(2025, 10, 1), LocalDate.of(2026, 3, 31));
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> rows(Object value) {
        return (List<Map<String, Object>>) value;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> map(Object value) {
        return (Map<String, Object>) value;
    }
}
