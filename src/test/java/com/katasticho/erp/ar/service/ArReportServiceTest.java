package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.AgeingReportResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
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
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ArReportServiceTest {

    @Mock private InvoiceRepository invoiceRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private TaxLineItemRepository taxLineItemRepository;

    private ArReportService reportService;
    private UUID orgId;
    private Contact contact;

    @BeforeEach
    void setUp() {
        reportService = new ArReportService(invoiceRepository, contactRepository, taxLineItemRepository);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);

        contact = Contact.builder().displayName("Acme Ltd").contactType(ContactType.CUSTOMER).build();
        contact.setId(UUID.randomUUID());
        contact.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void shouldCalculateAgeingBucketsCorrectly() {
        LocalDate asOfDate = LocalDate.of(2026, 4, 11);

        Invoice inv1 = Invoice.builder()
                .orgId(orgId).contactId(contact.getId())
                .invoiceNumber("INV-001").status("SENT")
                .dueDate(LocalDate.of(2026, 4, 15))
                .balanceDue(new BigDecimal("5000.00"))
                .build();
        inv1.setId(UUID.randomUUID());

        Invoice inv2 = Invoice.builder()
                .orgId(orgId).contactId(contact.getId())
                .invoiceNumber("INV-002").status("SENT")
                .dueDate(LocalDate.of(2026, 3, 20))
                .balanceDue(new BigDecimal("3000.00"))
                .build();
        inv2.setId(UUID.randomUUID());

        Invoice inv3 = Invoice.builder()
                .orgId(orgId).contactId(contact.getId())
                .invoiceNumber("INV-003").status("PARTIALLY_PAID")
                .dueDate(LocalDate.of(2026, 2, 25))
                .balanceDue(new BigDecimal("7000.00"))
                .build();
        inv3.setId(UUID.randomUUID());

        Invoice inv4 = Invoice.builder()
                .orgId(orgId).contactId(contact.getId())
                .invoiceNumber("INV-004").status("OVERDUE")
                .dueDate(LocalDate.of(2025, 12, 1))
                .balanceDue(new BigDecimal("10000.00"))
                .build();
        inv4.setId(UUID.randomUUID());

        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv1, inv2, inv3, inv4));
        when(contactRepository.findById(contact.getId())).thenReturn(Optional.of(contact));

        AgeingReportResponse report = reportService.getAgeingReport(asOfDate);

        assertNotNull(report);
        assertEquals(0, new BigDecimal("25000.00").compareTo(report.totalOutstanding()));
        assertEquals(0, new BigDecimal("5000.00").compareTo(report.current()));
        assertEquals(0, new BigDecimal("3000.00").compareTo(report.days1to30()));
        assertEquals(0, new BigDecimal("7000.00").compareTo(report.days31to60()));
        assertEquals(0, BigDecimal.ZERO.compareTo(report.days61to90()));
        assertEquals(0, new BigDecimal("10000.00").compareTo(report.days90plus()));

        assertEquals(1, report.contacts().size());
        assertEquals(4, report.contacts().get(0).invoices().size());
        assertEquals("CURRENT", report.contacts().get(0).invoices().get(0).bucket());
        assertEquals("1-30", report.contacts().get(0).invoices().get(1).bucket());
        assertEquals("31-60", report.contacts().get(0).invoices().get(2).bucket());
        assertEquals("90+", report.contacts().get(0).invoices().get(3).bucket());
    }

    @Test
    void shouldReturnEmptyReportWhenNoOutstandingInvoices() {
        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(List.of());

        AgeingReportResponse report = reportService.getAgeingReport(LocalDate.now());

        assertNotNull(report);
        assertEquals(0, BigDecimal.ZERO.compareTo(report.totalOutstanding()));
        assertTrue(report.contacts().isEmpty());
    }
}
