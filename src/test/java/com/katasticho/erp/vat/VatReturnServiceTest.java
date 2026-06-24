package com.katasticho.erp.vat;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.CreditNote;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.CreditNoteRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
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
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class VatReturnServiceTest {

    @Mock private InvoiceRepository invoiceRepo;
    @Mock private CreditNoteRepository creditNoteRepo;
    @Mock private PurchaseBillRepository billRepo;
    @Mock private TaxLineItemRepository taxLineRepo;

    private VatReturnService service;

    private final UUID orgId = UUID.randomUUID();
    private final LocalDate from = LocalDate.of(2026, 4, 1);
    private final LocalDate to = LocalDate.of(2026, 6, 30);

    @BeforeEach
    void setUp() {
        service = new VatReturnService(invoiceRepo, creditNoteRepo, billRepo, taxLineRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private TaxLineItem out(UUID sourceId, String sourceType, String amount, String tax) {
        return TaxLineItem.builder()
                .orgId(orgId).sourceType(sourceType).sourceId(sourceId)
                .taxRegime("VAT").componentCode("VAT").rate(new BigDecimal("5"))
                .taxableAmount(new BigDecimal(amount)).taxAmount(new BigDecimal(tax))
                .accountCode("2041").build();
    }

    private TaxLineItem in(UUID sourceId, String amount, String tax) {
        return TaxLineItem.builder()
                .orgId(orgId).sourceType("BILL").sourceId(sourceId)
                .taxRegime("VAT").componentCode("VAT").rate(new BigDecimal("5"))
                .taxableAmount(new BigDecimal(amount)).taxAmount(new BigDecimal(tax))
                .accountCode("1511").build();
    }

    @Test
    void uaeReturn_aggregatesInvoiceAndBillIntoBoxes() {
        UUID invId = UUID.randomUUID();
        UUID billId = UUID.randomUUID();
        Invoice inv = Invoice.builder().id(invId).orgId(orgId).build();
        PurchaseBill bill = PurchaseBill.builder().id(billId).orgId(orgId).build();
        when(invoiceRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of(inv));
        when(creditNoteRepo.findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(
                eq(orgId), eq(from), eq(to), eq("DRAFT"))).thenReturn(List.of());
        when(billRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of(bill));
        when(taxLineRepo.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                eq(orgId), eq(List.of("INVOICE", "CREDIT_NOTE")), eq("VAT"), anySet()))
                .thenReturn(List.of(out(invId, "INVOICE", "10000", "500")));
        when(taxLineRepo.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                eq(orgId), eq(List.of("BILL")), eq("VAT"), anySet()))
                .thenReturn(List.of(in(billId, "4000", "200")));

        VatReturnService.VatReturn r = service.uaeReturn(from, to);

        assertEquals(0, r.box1aStandardRatedSupplies().compareTo(new BigDecimal("10000")));
        assertEquals(0, r.box1bOutputVat().compareTo(new BigDecimal("500")));
        assertEquals(0, r.box9StandardRatedExpenses().compareTo(new BigDecimal("4000")));
        assertEquals(0, r.box10RecoverableInputVat().compareTo(new BigDecimal("200")));
        // Net due = 500 - 200 = 300
        assertEquals(0, r.box14NetVatDue().compareTo(new BigDecimal("300")));
        assertEquals(1, r.meta().get("invoiceCount"));
        assertEquals(1, r.meta().get("billCount"));
    }

    @Test
    void uaeReturn_creditNoteSubtractsFromOutput() {
        // 1 invoice 10000+500 VAT, 1 credit note 2000+100 VAT → net 8000/400.
        UUID invId = UUID.randomUUID();
        UUID cnId = UUID.randomUUID();
        Invoice inv = Invoice.builder().id(invId).orgId(orgId).build();
        CreditNote cn = CreditNote.builder().id(cnId).orgId(orgId).status("POSTED").build();
        when(invoiceRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of(inv));
        when(creditNoteRepo.findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(
                eq(orgId), eq(from), eq(to), eq("DRAFT"))).thenReturn(List.of(cn));
        when(billRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of());
        when(taxLineRepo.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                eq(orgId), eq(List.of("INVOICE", "CREDIT_NOTE")), eq("VAT"), anySet()))
                .thenReturn(List.of(
                        out(invId, "INVOICE", "10000", "500"),
                        out(cnId, "CREDIT_NOTE", "2000", "100")));
        // No bills → inputIds empty → BILL fetch short-circuits without a stub.

        VatReturnService.VatReturn r = service.uaeReturn(from, to);

        assertEquals(0, r.box1aStandardRatedSupplies().compareTo(new BigDecimal("8000")));
        assertEquals(0, r.box1bOutputVat().compareTo(new BigDecimal("400")));
        assertEquals(0, r.box14NetVatDue().compareTo(new BigDecimal("400")));
    }

    @Test
    void uaeReturn_cancelledCreditNoteExcluded() {
        // Credit note in CANCELLED status must not net against output.
        UUID invId = UUID.randomUUID();
        UUID cnId = UUID.randomUUID();
        Invoice inv = Invoice.builder().id(invId).orgId(orgId).build();
        CreditNote cancelled = CreditNote.builder().id(cnId).orgId(orgId).status("CANCELLED").build();
        when(invoiceRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of(inv));
        // Service-side filter drops CANCELLED — fixture returns both so we can
        // assert the filter rather than rely on the repository's status-not arg.
        when(creditNoteRepo.findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(
                eq(orgId), eq(from), eq(to), eq("DRAFT"))).thenReturn(List.of(cancelled));
        when(billRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of());
        // Cancelled CN never gets its tax lines fetched — only the invoice id is in the set.
        when(taxLineRepo.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                eq(orgId), eq(List.of("INVOICE", "CREDIT_NOTE")), eq("VAT"), anySet()))
                .thenReturn(List.of(out(invId, "INVOICE", "10000", "500")));
        // No bills → BILL fetch short-circuits.

        VatReturnService.VatReturn r = service.uaeReturn(from, to);
        assertEquals(0, r.box1aStandardRatedSupplies().compareTo(new BigDecimal("10000")));
        // Cancelled CN was filtered out by the service before counting.
        assertEquals(0, r.meta().get("creditNoteCount"));
    }

    @Test
    void uaeReturn_emptyPeriodReturnsZeros() {
        when(invoiceRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of());
        when(creditNoteRepo.findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(
                eq(orgId), eq(from), eq(to), eq("DRAFT"))).thenReturn(List.of());
        when(billRepo.findPostedByOrgAndDateRange(orgId, from, to)).thenReturn(List.of());

        VatReturnService.VatReturn r = service.uaeReturn(from, to);

        assertEquals(0, r.box1aStandardRatedSupplies().compareTo(BigDecimal.ZERO));
        assertEquals(0, r.box1bOutputVat().compareTo(BigDecimal.ZERO));
        assertEquals(0, r.box14NetVatDue().compareTo(BigDecimal.ZERO));
        // Empty source-id sets short-circuit the tax-line fetches.
        verify(taxLineRepo, never()).findByOrgAndSourceTypesAndRegimeAndSourceIds(
                any(), anyList(), anyString(), anySet());
    }

    @Test
    void uaeReturn_invalidRangeThrows() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.uaeReturn(to, from));
        assertEquals("VAT_INVALID_RANGE", ex.getErrorCode());
    }

    @Test
    void uaeReturn_nullRangeThrows() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.uaeReturn(null, to));
        assertEquals("VAT_INVALID_RANGE", ex.getErrorCode());
    }
}
