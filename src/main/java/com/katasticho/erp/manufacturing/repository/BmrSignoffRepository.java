package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.BmrSignoff;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BmrSignoffRepository extends JpaRepository<BmrSignoff, UUID> {

    Optional<BmrSignoff> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<BmrSignoff> findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderBySignedAtAsc(
            UUID orgId, UUID workOrderId);

    List<BmrSignoff> findByOrgIdAndJobCardIdAndIsDeletedFalseOrderBySignedAtAsc(
            UUID orgId, UUID jobCardId);
}
