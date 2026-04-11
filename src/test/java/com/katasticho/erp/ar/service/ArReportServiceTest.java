package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.AgeingReportResponse;
import com.katasticho.erp.ar.entity.Customer;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.CustomerRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
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
    @Mock private CustomerRepository customerRepository;
    @Mock private TaxLineItemRepository taxLineItemRepository;

    private ArReportService reportService;
    private UUID orgId;
    private Customer customer;

    @BeforeEach
    void setUp() {
        reportService = new ArReportService(invoiceRepository, customerRepository, taxLineItemRepository);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);

        customer = Customer.builder().name("Acme Ltd").build();
        customer.setId(UUID.randomUUID());
        customer.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void shouldCalculateAgeingBucketsCorrectly() {
        LocalDate asOfDate = LocalDate.of(2026, 4, 11);

        // Current (not overdue)
        Invoice inv1 = Invoice.builder()
                .orgId(orgId).customerId(customer.getId())
                .invoiceNumber("INV-001").status("SENT")
                .dueDate(LocalDate.of(2026, 4, 15)) // Due in 4 days — CURRENT
                .balanceDue(new BigDecimal("5000.00"))
                .build();
        inv1.setId(UUID.randomUUID());

        // 1-30 days overdue
        Invoice inv2 = Invoice.builder()
                .orgId(orgId).customerId(customer.getId())
                .invoiceNumber("INV-002").status("SENT")
                .dueDate(LocalDate.of(2026, 3, 20)) // 22 days overdue
                .balanceDue(new BigDecimal("3000.00"))
                .build();
        inv2.setId(UUID.randomUUID());

        // 31-60 days overdue
        Invoice inv3 = Invoice.builder()
                .orgId(orgId).customerId(customer.getId())
                .invoiceNumber("INV-003").status("PARTIALLY_PAID")
                .dueDate(LocalDate.of(2026, 2, 25)) // 45 days overdue
                .balanceDue(new BigDecimal("7000.00"))
                .build();
        inv3.setId(UUID.randomUUID());

        // 90+ days overdue
        Invoice inv4 = Invoice.builder()
                .orgId(orgId).customerId(customer.getId())
                .invoiceNumber("INV-004").status("OVERDUE")
                .dueDate(LocalDate.of(2025, 12, 1)) // ~131 days overdue
                .balanceDue(new BigDecimal("10000.00"))
                .build();
        inv4.setId(UUID.randomUUID());

        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv1, inv2, inv3, inv4));
        when(customerRepository.findById(customer.getId())).thenReturn(Optional.of(customer));

        AgeingReportResponse report = reportService.getAgeingReport(asOfDate);

        assertNotNull(report);
        assertEquals(0, new BigDecimal("25000.00").compareTo(report.totalOutstanding()));
        assertEquals(0, new BigDecimal("5000.00").compareTo(report.current()));
        assertEquals(0, new BigDecimal("3000.00").compareTo(report.days1to30()));
        assertEquals(0, new BigDecimal("7000.00").compareTo(report.days31to60()));
        assertEquals(0, BigDecimal.ZERO.compareTo(report.days61to90()));
        assertEquals(0, new BigDecimal("10000.00").compareTo(report.days90plus()));

        // Should have 1 customer with 4 invoices
        assertEquals(1, report.customers().size());
        assertEquals(4, report.customers().get(0).invoices().size());
        assertEquals("CURRENT", report.customers().get(0).invoices().get(0).bucket());
        assertEquals("1-30", report.customers().get(0).invoices().get(1).bucket());
        assertEquals("31-60", report.customers().get(0).invoices().get(2).bucket());
        assertEquals("90+", report.customers().get(0).invoices().get(3).bucket());
    }

    @Test
    void shouldReturnEmptyReportWhenNoOutstandingInvoices() {
        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(List.of());

        AgeingReportResponse report = reportService.getAgeingReport(LocalDate.now());

        assertNotNull(report);
        assertEquals(0, BigDecimal.ZERO.compareTo(report.totalOutstanding()));
        assertTrue(report.customers().isEmpty());
    }
}
