package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.BmrStepRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BmrStepRecordRepository extends JpaRepository<BmrStepRecord, UUID> {

    Optional<BmrStepRecord> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<BmrStepRecord> findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderByObservedAtAsc(
            UUID orgId, UUID workOrderId);

    List<BmrStepRecord> findByOrgIdAndJobCardIdAndIsDeletedFalseOrderByObservedAtAsc(
            UUID orgId, UUID jobCardId);
}
