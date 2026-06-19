package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.Item;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ItemRepository extends JpaRepository<Item, UUID> {

    Optional<Item> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<Item> findByOrgIdAndSkuAndIsDeletedFalse(UUID orgId, String sku);

    Optional<Item> findByOrgIdAndBarcodeAndIsDeletedFalse(UUID orgId, String barcode);

    boolean existsByOrgIdAndSkuAndIsDeletedFalse(UUID orgId, String sku);

    Page<Item> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    Page<Item> findByOrgIdAndIsDeletedFalseAndActiveTrue(UUID orgId, Pageable pageable);

    /**
     * Items changed since the cursor — feeds the POS catalog delta sync.
     * Cursor is composite ({@code updatedAt}, {@code id}) so a full pre-sync of
     * tens of thousands of rows that share a clock tick paginates correctly
     * (a pure timestamp cursor would re-fetch / stall on ties).
     */
    @Query("SELECT i FROM Item i WHERE i.orgId = :orgId " +
            "AND (i.updatedAt > :since OR (i.updatedAt = :since AND i.id > :sinceId)) " +
            "ORDER BY i.updatedAt ASC, i.id ASC")
    Page<Item> findChangedSince(@Param("orgId") UUID orgId,
                                @Param("since") java.time.Instant since,
                                @Param("sinceId") UUID sinceId,
                                Pageable pageable);

    /** Total active+deleted item count for the org — fuels pre-sync progress. */
    long countByOrgId(UUID orgId);

    @Query("""
            SELECT i FROM Item i
            WHERE i.orgId = :orgId
              AND i.isDeleted = false
              AND (LOWER(i.name) LIKE LOWER(CONCAT('%', :q, '%'))
                OR LOWER(i.sku)  LIKE LOWER(CONCAT('%', :q, '%')))
            """)
    Page<Item> search(@Param("orgId") UUID orgId, @Param("q") String q, Pageable pageable);

    Optional<Item> findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(UUID orgId, String name);

    List<Item> findByOrgIdAndIsDeletedFalseAndTrackInventoryTrue(UUID orgId);

    /**
     * Every active item for the org, name-sorted. Currently used by
     * the FSSAI allergen-exposure report (filters in Java after
     * pulling the list, so it doesn't need a JSONB-contains query
     * yet).
     */
    List<Item> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    /** Bulk id lookup used by services that need to enrich DTOs with item
     * name/SKU in one round trip — see {@code PriceListService.listItemsEnriched}. */
    List<Item> findByOrgIdAndIsDeletedFalseAndIdIn(UUID orgId, Collection<UUID> ids);

    /** Variants under one group — used by the F5 group detail screen
     * and by the matrix bulk-create dedupe path. Ordered by SKU so the
     * variant grid renders predictably. */
    List<Item> findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(UUID orgId, UUID groupId);

    /** Existence guard for the F5 group delete path — refuses to
     * soft-delete a group while live children still point at it. */
    boolean existsByOrgIdAndGroupIdAndIsDeletedFalse(UUID orgId, UUID groupId);
}
