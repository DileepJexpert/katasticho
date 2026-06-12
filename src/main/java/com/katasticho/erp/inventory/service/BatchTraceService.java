package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.BatchTrace;
import com.katasticho.erp.inventory.repository.BatchTraceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class BatchTraceService {

    private final BatchTraceRepository batchTraceRepo;

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
        trace = batchTraceRepo.save(trace);

        // Also record the forward trace from source perspective
        BatchTrace forwardTrace = BatchTrace.builder()
                .batchId(sourceBatchId)
                .itemId(sourceItemId)
                .traceType("FORWARD")
                .sourceBatchId(sourceBatchId)
                .sourceItemId(sourceItemId)
                .workOrderId(workOrderId)
                .movementId(movementId)
                .quantity(quantity)
                .tracedAt(Instant.now())
                .build();
        batchTraceRepo.save(forwardTrace);

        log.info("Recorded batch trace: RM batch {} → FG batch {} via WO {}", sourceBatchId, fgBatchId, workOrderId);
        return trace;
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
