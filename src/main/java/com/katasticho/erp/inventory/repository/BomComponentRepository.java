package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.BomComponent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for {@link BomComponent}. The {@code
 * findByOrgIdAndParentItemIdAndIsDeletedFalse} method is the BOM
 * explosion hot path called from {@code
 * InventoryService.deductStockForInvoice()} once per composite invoice
 * line, and the {@code V16} index on
 * {@code (parent_item_id) WHERE NOT is_deleted} backs it.
 */
@Repository
public interface BomComponentRepository extends JpaRepository<BomComponent, UUID> {

    /** Single tenant-scoped row lookup for CRUD / delete paths. */
    Optional<BomComponent> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /**
     * All live BOM rows for one parent. Used both by the controller
     * (list/detail) and by the invoice-send explosion. Ordered by
     * {@code createdAt} so the UI shows children in insertion order.
     */
    List<BomComponent> findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, UUID parentItemId);

    /** Guard for duplicate (parent, child) inserts — the partial unique
     * index will reject anyway, but the service surfaces a friendlier
     * {@code BOM_DUPLICATE_CHILD} error first. */
    boolean existsByOrgIdAndParentItemIdAndChildItemIdAndIsDeletedFalse(
            UUID orgId, UUID parentItemId, UUID childItemId);
}
