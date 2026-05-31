package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.CustomerRiskResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.ReminderLogRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CreditReminderServiceTest {

    @Mock private InvoiceRepository invoiceRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private ReminderLogRepository reminderLogRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private OrgSettingsService orgSettingsService;

    private CreditReminderService service;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        service = new CreditReminderService(
                invoiceRepository,
                contactRepository,
                reminderLogRepository,
                organisationRepository,
                orgSettingsService);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void getCustomerRisk_returnsEmptyWhenNoOutstandingOrSalesHold() {
        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(List.of());
        when(contactRepository.findActiveCustomerSalesHolds(eq(orgId), any(LocalDate.class))).thenReturn(List.of());

        List<CustomerRiskResponse> result = service.getCustomerRisk();

        assertTrue(result.isEmpty());
        verify(contactRepository, never()).findByOrgIdAndIsDeletedFalseAndIdIn(any(), any());
    }

    @Test
    void getCustomerRisk_flagsSalesHoldAndSortsItFirst() {
        Contact overCredit = customer("Over Credit", new BigDecimal("1000.00"), false);
        Contact salesHold = customer("Sales Hold", new BigDecimal("10000.00"), true);
        salesHold.setSalesHoldReason("Owner approval required");

        Invoice invoice = invoice(overCredit.getId(), "INV-001", new BigDecimal("1500.00"), LocalDate.now().plusDays(5));

        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(List.of(invoice));
        when(contactRepository.findActiveCustomerSalesHolds(eq(orgId), any(LocalDate.class))).thenReturn(List.of(salesHold));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(overCredit, salesHold));

        List<CustomerRiskResponse> result = service.getCustomerRisk();

        assertEquals(2, result.size());
        assertEquals(salesHold.getId(), result.get(0).contactId());
        assertEquals("SALES_HOLD", result.get(0).riskLevel());
        assertTrue(result.get(0).salesHold());
        assertEquals("Owner approval required", result.get(0).salesHoldReason());

        assertEquals(overCredit.getId(), result.get(1).contactId());
        assertEquals("OVER_CREDIT", result.get(1).riskLevel());
        assertEquals(0, new BigDecimal("150.00").compareTo(result.get(1).creditUtilizationPercent()));
        assertTrue(result.get(1).reasons().contains("Outstanding exceeds credit limit"));
    }

    @Test
    void getCustomerRisk_countsOverdueInvoicesAndAmounts() {
        Contact customer = customer("Late Customer", new BigDecimal("5000.00"), false);
        Invoice overdue = invoice(customer.getId(), "INV-OLD", new BigDecimal("900.00"), LocalDate.now().minusDays(12));
        Invoice current = invoice(customer.getId(), "INV-NEW", new BigDecimal("100.00"), LocalDate.now().plusDays(2));

        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(List.of(overdue, current));
        when(contactRepository.findActiveCustomerSalesHolds(eq(orgId), any(LocalDate.class))).thenReturn(List.of());
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any())).thenReturn(List.of(customer));

        List<CustomerRiskResponse> result = service.getCustomerRisk();

        assertEquals(1, result.size());
        CustomerRiskResponse risk = result.get(0);
        assertEquals("OVERDUE", risk.riskLevel());
        assertEquals(2, risk.invoiceCount());
        assertEquals(1, risk.overdueInvoiceCount());
        assertEquals(12, risk.maxDaysOverdue());
        assertEquals(0, new BigDecimal("1000.00").compareTo(risk.outstandingAr()));
        assertEquals(0, new BigDecimal("900.00").compareTo(risk.overdueAmount()));
        assertTrue(risk.reasons().contains("1 overdue invoice(s)"));
    }

    private Contact customer(String name, BigDecimal creditLimit, boolean salesHold) {
        Contact contact = Contact.builder()
                .displayName(name)
                .contactType(ContactType.CUSTOMER)
                .creditLimit(creditLimit)
                .outstandingAr(BigDecimal.ZERO)
                .salesHold(salesHold)
                .build();
        contact.setId(UUID.randomUUID());
        contact.setOrgId(orgId);
        return contact;
    }

    private Invoice invoice(UUID contactId, String number, BigDecimal balanceDue, LocalDate dueDate) {
        Invoice invoice = Invoice.builder()
                .orgId(orgId)
                .contactId(contactId)
                .invoiceNumber(number)
                .invoiceDate(LocalDate.now())
                .dueDate(dueDate)
                .status("SENT")
                .totalAmount(balanceDue)
                .balanceDue(balanceDue)
                .build();
        invoice.setId(UUID.randomUUID());
        return invoice;
    }
}
