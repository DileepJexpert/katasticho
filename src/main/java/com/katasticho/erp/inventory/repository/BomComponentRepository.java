package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.BomComponent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.Query;

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

    /** Version-aware duplicate-child guard: only checks the CURRENT (max) version
     * so a child that exists in an OLD version doesn't block editing the new one. */
    @Query("SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END FROM BomComponent b "
            + "WHERE b.orgId = :orgId AND b.parentItemId = :parentItemId AND b.childItemId = :childItemId "
            + "AND b.isDeleted = false AND b.version = ("
            + "  SELECT COALESCE(MAX(b2.version), 1) FROM BomComponent b2 "
            + "  WHERE b2.orgId = :orgId AND b2.parentItemId = :parentItemId AND b2.isDeleted = false)")
    boolean existsInCurrentBom(UUID orgId, UUID parentItemId, UUID childItemId);

    @Query("SELECT COALESCE(MAX(b.version), 0) FROM BomComponent b " +
           "WHERE b.orgId = :orgId AND b.parentItemId = :parentItemId AND b.isDeleted = false")
    int findMaxVersion(UUID orgId, UUID parentItemId);

    List<BomComponent> findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, UUID parentItemId, int version);

    /**
     * The CURRENT (latest-version) BOM for a parent. createBomVersion keeps old
     * versions live as history, so every "current BOM" consumer must filter to the
     * max version — otherwise it would see v1+v2 rows together and double every
     * component's quantity/cost. Version-specific readers keep the version finder.
     */
    @Query("SELECT b FROM BomComponent b WHERE b.orgId = :orgId AND b.parentItemId = :parentItemId "
            + "AND b.isDeleted = false AND b.version = ("
            + "  SELECT COALESCE(MAX(b2.version), 1) FROM BomComponent b2 "
            + "  WHERE b2.orgId = :orgId AND b2.parentItemId = :parentItemId AND b2.isDeleted = false) "
            + "ORDER BY b.createdAt")
    List<BomComponent> findCurrentBom(UUID orgId, UUID parentItemId);
}
