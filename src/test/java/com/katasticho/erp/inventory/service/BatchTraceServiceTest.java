package com.katasticho.erp.inventory.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.BatchTrace;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.BatchTraceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BatchTraceServiceTest {

    @Mock private BatchTraceRepository batchTraceRepo;
    @Mock private StockMovementRepository stockMovementRepo;
    @Mock private StockBatchRepository stockBatchRepo;
    @Mock private InvoiceRepository invoiceRepo;
    @Mock private ContactRepository contactRepo;

    private BatchTraceService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new BatchTraceService(batchTraceRepo, stockMovementRepo,
                stockBatchRepo, invoiceRepo, contactRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private StockMovement issueMovement(UUID itemId, UUID batchId, UUID woId, double qty) {
        StockMovement m = StockMovement.builder()
                .itemId(itemId)
                .batchId(batchId)
                .movementType(MovementType.PRODUCTION_ISSUE)
                .quantity(BigDecimal.valueOf(-qty))
                .referenceType(ReferenceType.WORK_ORDER)
                .referenceId(woId)
                .build();
        m.setId(UUID.randomUUID());
        return m;
    }

    private StockMovement saleMovement(UUID itemId, UUID batchId, UUID invoiceId,
                                       String invoiceNumber, LocalDate date, double qty) {
        StockMovement m = StockMovement.builder()
                .itemId(itemId)
                .batchId(batchId)
                .movementType(MovementType.SALE)
                .quantity(BigDecimal.valueOf(-qty))
                .movementDate(date)
                .referenceType(ReferenceType.INVOICE)
                .referenceId(invoiceId)
                .referenceNumber(invoiceNumber)
                .build();
        m.setId(UUID.randomUUID());
        return m;
    }

    @Test
    void linkTracesForFgReceipt_writesOneBackwardRowPerUniqueRmBatch() {
        UUID woId = UUID.randomUUID();
        UUID fgBatch = UUID.randomUUID();
        UUID fgItem = UUID.randomUUID();
        UUID rmA = UUID.randomUUID();
        UUID rmB = UUID.randomUUID();
        UUID rmItem = UUID.randomUUID();
        when(stockMovementRepo.findByReferenceTypeAndReferenceId(ReferenceType.WORK_ORDER, woId))
                .thenReturn(List.of(
                        issueMovement(rmItem, rmA, woId, 5),
                        issueMovement(rmItem, rmA, woId, 3), // same RM batch twice
                        issueMovement(rmItem, rmB, woId, 7),
                        issueMovement(rmItem, null, woId, 2) // un-batched: ignored
                ));
        when(batchTraceRepo.existsByOrgIdAndBatchIdAndSourceBatchIdAndWorkOrderIdAndTraceTypeAndIsDeletedFalse(
                eq(orgId), eq(fgBatch), any(), eq(woId), eq("BACKWARD"))).thenReturn(false);
        when(batchTraceRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        int linked = service.linkTracesForFgReceipt(woId, fgBatch, fgItem);

        assertEquals(2, linked, "Two unique RM batches → two BACKWARD rows");
        // recordTrace writes 1 BACKWARD + 1 FORWARD per call → 4 saves total.
        verify(batchTraceRepo, times(4)).save(any());
    }

    @Test
    void linkTracesForFgReceipt_dedupesAcrossPartialReceipts() {
        UUID woId = UUID.randomUUID();
        UUID fgBatch = UUID.randomUUID();
        UUID rmA = UUID.randomUUID();
        UUID rmItem = UUID.randomUUID();
        when(stockMovementRepo.findByReferenceTypeAndReferenceId(ReferenceType.WORK_ORDER, woId))
                .thenReturn(List.of(issueMovement(rmItem, rmA, woId, 5)));
        // Trace already exists from an earlier partial receipt.
        when(batchTraceRepo.existsByOrgIdAndBatchIdAndSourceBatchIdAndWorkOrderIdAndTraceTypeAndIsDeletedFalse(
                eq(orgId), eq(fgBatch), eq(rmA), eq(woId), eq("BACKWARD"))).thenReturn(true);

        int linked = service.linkTracesForFgReceipt(woId, fgBatch, UUID.randomUUID());

        assertEquals(1, linked, "linkTraces still counts each unique RM batch — dedupe lives inside recordTrace");
        verify(batchTraceRepo, never()).save(any());
    }

    @Test
    void linkTracesForFgReceipt_nullFgBatch_noop() {
        int linked = service.linkTracesForFgReceipt(UUID.randomUUID(), null, UUID.randomUUID());
        assertEquals(0, linked);
        verify(stockMovementRepo, never()).findByReferenceTypeAndReferenceId(any(), any());
    }

    @Test
    void recallReport_walksRmToFgToCustomerShipments() {
        UUID rmBatch = UUID.randomUUID();
        UUID rmItem = UUID.randomUUID();
        UUID fgBatch = UUID.randomUUID();
        UUID fgItem = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();

        StockBatch rm = StockBatch.builder().itemId(rmItem).batchNumber("RM-2026-07").build();
        rm.setId(rmBatch);
        when(stockBatchRepo.findByIdAndOrgIdAndIsDeletedFalse(rmBatch, orgId))
                .thenReturn(Optional.of(rm));

        StockBatch fg = StockBatch.builder().itemId(fgItem).batchNumber("FG-2026-A").build();
        fg.setId(fgBatch);
        when(stockBatchRepo.findByIdAndOrgIdAndIsDeletedFalse(fgBatch, orgId))
                .thenReturn(Optional.of(fg));

        BatchTrace backward = BatchTrace.builder()
                .batchId(fgBatch).itemId(fgItem)
                .sourceBatchId(rmBatch).sourceItemId(rmItem)
                .traceType("BACKWARD").workOrderId(UUID.randomUUID())
                .build();
        when(batchTraceRepo.findByOrgIdAndSourceBatchIdAndIsDeletedFalseOrderByTracedAtAsc(orgId, rmBatch))
                .thenReturn(List.of(backward));

        StockMovement sale = saleMovement(fgItem, fgBatch, invoiceId, "INV-001",
                LocalDate.now(), 12);
        when(stockMovementRepo.findSaleMovementsByBatch(orgId, fgBatch)).thenReturn(List.of(sale));
        Invoice inv = Invoice.builder().id(invoiceId).invoiceNumber("INV-001").contactId(contactId).build();
        when(invoiceRepo.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)).thenReturn(Optional.of(inv));
        Contact c = new Contact();
        c.setDisplayName("Acme Pharmacy");
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)).thenReturn(Optional.of(c));

        Map<String, Object> report = service.recallReport(rmBatch);

        assertEquals(1, report.get("affectedFgBatchCount"));
        assertEquals(1, report.get("affectedShipmentCount"));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> shipments = (List<Map<String, Object>>) report.get("affectedShipments");
        assertEquals("Acme Pharmacy", shipments.get(0).get("customerName"));
        assertEquals("INV-001", shipments.get(0).get("invoiceNumber"));
        assertEquals(0, ((BigDecimal) shipments.get(0).get("quantity")).compareTo(BigDecimal.valueOf(12)));
    }

    @Test
    void recallReport_emptyTrace_returnsZeroCounts() {
        UUID rmBatch = UUID.randomUUID();
        when(stockBatchRepo.findByIdAndOrgIdAndIsDeletedFalse(rmBatch, orgId))
                .thenReturn(Optional.empty());
        when(batchTraceRepo.findByOrgIdAndSourceBatchIdAndIsDeletedFalseOrderByTracedAtAsc(orgId, rmBatch))
                .thenReturn(List.of());

        Map<String, Object> report = service.recallReport(rmBatch);

        assertEquals(0, report.get("affectedFgBatchCount"));
        assertEquals(0, report.get("affectedShipmentCount"));
    }

    @Test
    void recordTrace_dedupesOnSameFgRmWoTriple() {
        UUID fgBatch = UUID.randomUUID();
        UUID rmBatch = UUID.randomUUID();
        UUID woId = UUID.randomUUID();
        when(batchTraceRepo.existsByOrgIdAndBatchIdAndSourceBatchIdAndWorkOrderIdAndTraceTypeAndIsDeletedFalse(
                orgId, fgBatch, rmBatch, woId, "BACKWARD")).thenReturn(true);

        BatchTrace result = service.recordTrace(fgBatch, UUID.randomUUID(),
                rmBatch, UUID.randomUUID(), woId, UUID.randomUUID(), BigDecimal.ONE);

        assertNull(result);
        verify(batchTraceRepo, never()).save(any());
    }

    @Test
    void recordTrace_writesBothBackwardAndForwardRows_withCorrectFgLink() {
        UUID fgBatch = UUID.randomUUID();
        UUID fgItem = UUID.randomUUID();
        UUID rmBatch = UUID.randomUUID();
        UUID rmItem = UUID.randomUUID();
        UUID woId = UUID.randomUUID();
        when(batchTraceRepo.existsByOrgIdAndBatchIdAndSourceBatchIdAndWorkOrderIdAndTraceTypeAndIsDeletedFalse(
                any(), any(), any(), any(), any())).thenReturn(false);
        when(batchTraceRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.recordTrace(fgBatch, fgItem, rmBatch, rmItem, woId, UUID.randomUUID(), BigDecimal.TEN);

        ArgumentCaptor<BatchTrace> cap = ArgumentCaptor.forClass(BatchTrace.class);
        verify(batchTraceRepo, times(2)).save(cap.capture());
        BatchTrace backward = cap.getAllValues().get(0);
        BatchTrace forward = cap.getAllValues().get(1);
        assertEquals("BACKWARD", backward.getTraceType());
        assertEquals(fgBatch, backward.getBatchId());
        assertEquals(rmBatch, backward.getSourceBatchId());
        assertEquals("FORWARD", forward.getTraceType());
        assertEquals(rmBatch, forward.getBatchId());
        assertEquals(fgBatch, forward.getSourceBatchId(),
                "Forward row must point sourceBatchId at FG so 'where did this RM go' walks correctly");
    }
}
