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
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class BatchTraceService {

    private final BatchTraceRepository batchTraceRepo;
    private final StockMovementRepository stockMovementRepo;
    private final StockBatchRepository stockBatchRepo;
    private final InvoiceRepository invoiceRepo;
    private final ContactRepository contactRepo;

    /**
     * Forward trace: given a raw-material batch, find all finished-goods batches
     * it was consumed into (via work orders).
     */
    @Transactional(readOnly = true)
    public List<BatchTrace> traceForward(UUID batchId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return batchTraceRepo.findByOrgIdAndSourceBatchIdAndIsDeletedFalseOrderByTracedAtAsc(orgId, batchId);
    }

    /**
     * Backward trace: given a finished-goods batch, find source RM batches and work orders.
     */
    @Transactional(readOnly = true)
    public List<BatchTrace> traceBackward(UUID batchId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return batchTraceRepo.findByOrgIdAndBatchIdAndIsDeletedFalseOrderByTracedAtAsc(orgId, batchId);
    }

    /**
     * Record a single trace entry linking a source RM batch to an output FG batch via a work order.
     */
    @Transactional
    public BatchTrace recordTrace(UUID fgBatchId, UUID fgItemId,
                                  UUID sourceBatchId, UUID sourceItemId,
                                  UUID workOrderId, UUID movementId,
                                  BigDecimal quantity) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Partial FG receipts on the same WO trigger this code multiple
        // times — without dedupe each pass would insert a duplicate
        // (fg, rm, wo) link and the recall report would over-count.
        if (batchTraceRepo
                .existsByOrgIdAndBatchIdAndSourceBatchIdAndWorkOrderIdAndTraceTypeAndIsDeletedFalse(
                        orgId, fgBatchId, sourceBatchId, workOrderId, "BACKWARD")) {
            return null;
        }

        BatchTrace trace = BatchTrace.builder()
                .batchId(fgBatchId)
                .itemId(fgItemId)
                .traceType("BACKWARD")
                .sourceBatchId(sourceBatchId)
                .sourceItemId(sourceItemId)
                .workOrderId(workOrderId)
                .movementId(movementId)
                .quantity(quantity)
                .tracedAt(Instant.now())
                .build();
        trace.setOrgId(orgId);
        trace = batchTraceRepo.save(trace);

        // Also record the forward trace from source perspective. NOTE:
        // batchId stays on the RM batch (so this row sorts under the RM
        // when listed by batchId) while sourceBatchId points at the FG
        // batch — that way "where did this RM go?" can read sourceBatchId
        // for the FG output. (The original implementation set
        // sourceBatchId=sourceBatchId which lost the FG link entirely.)
        BatchTrace forwardTrace = BatchTrace.builder()
                .batchId(sourceBatchId)
                .itemId(sourceItemId)
                .traceType("FORWARD")
                .sourceBatchId(fgBatchId)
                .sourceItemId(fgItemId)
                .workOrderId(workOrderId)
                .movementId(movementId)
                .quantity(quantity)
                .tracedAt(Instant.now())
                .build();
        forwardTrace.setOrgId(orgId);
        batchTraceRepo.save(forwardTrace);

        log.info("Recorded batch trace: RM batch {} → FG batch {} via WO {}", sourceBatchId, fgBatchId, workOrderId);
        return trace;
    }

    /**
     * Called by ManufacturingService after each FG receipt to wire RM↔FG
     * traces from the WO's actual stock movements. Walks every
     * PRODUCTION_ISSUE movement on the WO that carries a batch id and
     * records one (rm → fg) trace per unique RM batch.
     *
     * Idempotent: dedupe inside {@link #recordTrace} swallows repeats so
     * partial FG receipts on the same WO can call this method as many
     * times as they want without duplicating links.
     */
    @Transactional
    public int linkTracesForFgReceipt(UUID workOrderId, UUID fgBatchId, UUID fgItemId) {
        if (fgBatchId == null) return 0;       // FG item doesn't track batches; nothing to trace.
        List<StockMovement> issued = stockMovementRepo
                .findByReferenceTypeAndReferenceId(ReferenceType.WORK_ORDER, workOrderId);
        int linked = 0;
        Set<UUID> seenRm = new HashSet<>();
        for (StockMovement m : issued) {
            if (m.getMovementType() != MovementType.PRODUCTION_ISSUE) continue;
            if (m.getBatchId() == null) continue;
            if (!seenRm.add(m.getBatchId())) continue;     // one trace row per (rm, fg, wo)
            recordTrace(fgBatchId, fgItemId, m.getBatchId(), m.getItemId(),
                    workOrderId, m.getId(),
                    m.getQuantity() != null ? m.getQuantity().abs() : null);
            linked++;
        }
        return linked;
    }

    /**
     * Batch recall (tracker #47). Given a (potentially defective) raw-
     * material batch id, returns every finished-goods batch it was ever
     * mixed into AND every downstream sales movement of those FG batches
     * so the recall team can phone the affected customers.
     *
     * <p>The response shape is intentionally flat — one list of "affected
     * shipments" — so the UI can show it as a single, sortable table.
     * Each row carries the FG batch number, qty shipped, invoice number,
     * customer name (when resolvable) and the shipment date.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> recallReport(UUID rmBatchId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Map<String, Object> out = new LinkedHashMap<>();
        StockBatch rm = stockBatchRepo.findByIdAndOrgIdAndIsDeletedFalse(rmBatchId, orgId).orElse(null);
        Map<String, Object> rmInfo = new LinkedHashMap<>();
        rmInfo.put("batchId", rmBatchId);
        rmInfo.put("batchNumber", rm == null ? null : rm.getBatchNumber());
        rmInfo.put("itemId", rm == null ? null : rm.getItemId());
        rmInfo.put("expiryDate", rm == null ? null : rm.getExpiryDate());
        out.put("rmBatch", rmInfo);

        // Affected FG batches via the BACKWARD trace rows (sourceBatchId=rm).
        List<BatchTrace> backRows = batchTraceRepo
                .findByOrgIdAndSourceBatchIdAndIsDeletedFalseOrderByTracedAtAsc(orgId, rmBatchId)
                .stream()
                .filter(t -> "BACKWARD".equals(t.getTraceType()))
                .toList();

        Set<UUID> fgBatchIds = backRows.stream()
                .map(BatchTrace::getBatchId)
                .filter(Objects::nonNull)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        List<Map<String, Object>> affectedFgBatches = new ArrayList<>();
        for (UUID fgBatchId : fgBatchIds) {
            StockBatch fg = stockBatchRepo.findByIdAndOrgIdAndIsDeletedFalse(fgBatchId, orgId).orElse(null);
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("fgBatchId", fgBatchId);
            row.put("fgBatchNumber", fg == null ? null : fg.getBatchNumber());
            row.put("fgItemId", fg == null ? null : fg.getItemId());
            affectedFgBatches.add(row);
        }
        out.put("affectedFgBatches", affectedFgBatches);

        // Forward walk — every SALE movement of an affected FG batch is a
        // shipment that may need to be recalled.
        List<Map<String, Object>> shipments = new ArrayList<>();
        for (UUID fgBatchId : fgBatchIds) {
            for (StockMovement m : stockMovementRepo.findSaleMovementsByBatch(orgId, fgBatchId)) {
                if (m.getReferenceType() != ReferenceType.INVOICE || m.getReferenceId() == null) continue;
                Invoice inv = invoiceRepo.findByIdAndOrgIdAndIsDeletedFalse(m.getReferenceId(), orgId).orElse(null);
                String customer = null;
                String invoiceNumber = m.getReferenceNumber();
                if (inv != null) {
                    invoiceNumber = inv.getInvoiceNumber();
                    Contact c = contactRepo.findByIdAndOrgIdAndIsDeletedFalse(inv.getContactId(), orgId).orElse(null);
                    if (c != null) {
                        customer = c.getDisplayName() != null ? c.getDisplayName() : c.getCompanyName();
                    }
                }
                Map<String, Object> ship = new LinkedHashMap<>();
                ship.put("fgBatchId", fgBatchId);
                ship.put("movementDate", m.getMovementDate());
                ship.put("quantity", m.getQuantity() == null ? BigDecimal.ZERO : m.getQuantity().abs());
                ship.put("invoiceId", inv == null ? null : inv.getId());
                ship.put("invoiceNumber", invoiceNumber);
                ship.put("customerName", customer);
                shipments.add(ship);
            }
        }
        // Most-recent first — recall calls go out to the latest customers first.
        shipments.sort((a, b) -> {
            Object da = a.get("movementDate");
            Object db = b.get("movementDate");
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.toString().compareTo(da.toString());
        });
        out.put("affectedShipments", shipments);
        out.put("affectedFgBatchCount", fgBatchIds.size());
        out.put("affectedShipmentCount", shipments.size());
        return out;
    }

    /**
     * Get full trace history for a batch (both as FG batch and as RM source).
     */
    @Transactional(readOnly = true)
    public Map<String, List<BatchTrace>> getTraceHistory(UUID batchId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<BatchTrace> backward = batchTraceRepo
                .findByOrgIdAndBatchIdAndIsDeletedFalseOrderByTracedAtAsc(orgId, batchId);
        List<BatchTrace> forward = batchTraceRepo
                .findByOrgIdAndSourceBatchIdAndIsDeletedFalseOrderByTracedAtAsc(orgId, batchId);

        Map<String, List<BatchTrace>> result = new LinkedHashMap<>();
        result.put("backward", backward);   // where this FG batch came from
        result.put("forward", forward);     // where this RM batch went to
        return result;
    }
}
