package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.BomCoProduct;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BomCoProductRepository extends JpaRepository<BomCoProduct, UUID> {

    Optional<BomCoProduct> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<BomCoProduct> findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, UUID parentItemId);

    boolean existsByOrgIdAndParentItemIdAndCoProductItemIdAndIsDeletedFalse(
            UUID orgId, UUID parentItemId, UUID coProductItemId);
}
