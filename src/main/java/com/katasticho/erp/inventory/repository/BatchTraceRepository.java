package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.BatchTrace;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface BatchTraceRepository extends JpaRepository<BatchTrace, UUID> {

    List<BatchTrace> findByOrgIdAndBatchIdAndIsDeletedFalseOrderByTracedAtAsc(UUID orgId, UUID batchId);

    List<BatchTrace> findByOrgIdAndSourceBatchIdAndIsDeletedFalseOrderByTracedAtAsc(UUID orgId, UUID sourceBatchId);

    List<BatchTrace> findByOrgIdAndWorkOrderIdAndIsDeletedFalse(UUID orgId, UUID workOrderId);
}
