package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.ReorderPolicy;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ReorderPolicyRepository extends JpaRepository<ReorderPolicy, UUID> {

    Optional<ReorderPolicy> findByOrgIdAndItemIdAndWarehouseIdAndIsDeletedFalse(UUID orgId, UUID itemId, UUID warehouseId);

    Optional<ReorderPolicy> findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(UUID orgId, UUID itemId);

    List<ReorderPolicy> findByOrgIdAndIsDeletedFalseOrderByAbcClassAsc(UUID orgId);

    List<ReorderPolicy> findByOrgIdAndAbcClassAndIsDeletedFalse(UUID orgId, String abcClass);

    List<ReorderPolicy> findByOrgIdAndAutoReorderTrueAndIsDeletedFalse(UUID orgId);
}
