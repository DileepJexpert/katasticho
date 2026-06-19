package com.katasticho.erp.fieldforce.service;

import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.contact.service.ContactService;
import com.katasticho.erp.fieldsales.service.FieldSalesService;
import com.katasticho.erp.fieldsales.service.FieldTrackingService;
import com.katasticho.erp.sales.service.SalesOrderService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.PageImpl;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class FieldFacadeServiceTest {

    @Mock private FieldSalesService fieldSalesService;
    @Mock private FieldTrackingService fieldTrackingService;
    @Mock private ContactService contactService;
    @Mock private ContactLedgerService contactLedgerService;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private SalesOrderService salesOrderService;
    @Mock private PaymentService paymentService;
    private FieldFacadeService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID dealerId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FieldFacadeService(fieldSalesService, fieldTrackingService, contactService,
                contactLedgerService, invoiceRepository, salesOrderService, paymentService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(paymentService.recordPayment(any())).thenAnswer(i ->
                Payment.builder().id(UUID.randomUUID()).build());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Invoice invoice(String number, LocalDate date, String balance) {
        return Invoice.builder().id(UUID.randomUUID()).orgId(orgId).contactId(dealerId)
                .invoiceNumber(number).invoiceDate(date)
                .totalAmount(new BigDecimal(balance)).balanceDue(new BigDecimal(balance)).build();
    }

    @Test
    void recordCollection_allocatesOldestFirstAcrossInvoices() {
        // Returned newest-first by the repo; the service must allocate oldest-first.
        Invoice newer = invoice("INV-2", LocalDate.of(2026, 5, 10), "3000");
        Invoice older = invoice("INV-1", LocalDate.of(2026, 4, 1), "2000");
        when(invoiceRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                eq(orgId), eq(dealerId), any()))
                .thenReturn(new PageImpl<>(List.of(newer, older)));

        // Collect ₹2500 → fully clears the older (2000), partially the newer (500).
        Map<String, Object> r = service.recordCollection(dealerId, new BigDecimal("2500"), "CASH", null);

        assertEquals(0, new BigDecimal("2500").compareTo((BigDecimal) r.get("allocated")));
        assertEquals(0, BigDecimal.ZERO.compareTo((BigDecimal) r.get("unallocated")));

        ArgumentCaptor<RecordPaymentRequest> cap = ArgumentCaptor.forClass(RecordPaymentRequest.class);
        verify(paymentService, times(2)).recordPayment(cap.capture());
        List<RecordPaymentRequest> calls = cap.getAllValues();
        // First payment goes to the OLDER invoice for its full balance.
        assertEquals(older.getId(), calls.get(0).invoiceId());
        assertEquals(0, new BigDecimal("2000").compareTo(calls.get(0).amount()));
        // Second payment is the ₹500 remainder against the newer invoice.
        assertEquals(newer.getId(), calls.get(1).invoiceId());
        assertEquals(0, new BigDecimal("500").compareTo(calls.get(1).amount()));
    }

    @Test
    void recordCollection_excessOverOpenBalance_reportsUnallocated() {
        Invoice only = invoice("INV-1", LocalDate.of(2026, 4, 1), "1000");
        when(invoiceRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                eq(orgId), eq(dealerId), any()))
                .thenReturn(new PageImpl<>(List.of(only)));

        Map<String, Object> r = service.recordCollection(dealerId, new BigDecimal("1500"), "UPI", null);

        assertEquals(0, new BigDecimal("1000").compareTo((BigDecimal) r.get("allocated")));
        assertEquals(0, new BigDecimal("500").compareTo((BigDecimal) r.get("unallocated")));
        verify(paymentService, times(1)).recordPayment(any());
        assertNotNull(r.get("note"));
    }

    @Test
    void recordCollection_nonPositiveAmount_throws() {
        assertThrows(RuntimeException.class,
                () -> service.recordCollection(dealerId, BigDecimal.ZERO, "CASH", null));
        verify(paymentService, never()).recordPayment(any());
    }
}
