package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.StockBatch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockBatchRepository extends JpaRepository<StockBatch, UUID> {

    Optional<StockBatch> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /**
     * Upsert helper — looks up an existing batch row by the natural
     * key {@code (org_id, item_id, batch_number)} so re-receiving the
     * same batch from the same supplier adds qty to the existing row
     * instead of duplicating it.
     */
    Optional<StockBatch> findByOrgIdAndItemIdAndBatchNumberAndIsDeletedFalse(
            UUID orgId, UUID itemId, String batchNumber);

    /**
     * THE FEFO QUERY.
     *
     * <p>Returns every non-deleted, active batch for an item that still
     * has on-hand quantity &gt; 0 in the given warehouse, ordered by
     * expiry date ascending. Batches with NULL expiry sort last so
     * dated stock always moves before non-dated stock.
     *
     * <p>The join against {@code stock_batch_balance} is what makes the
     * picker skip empty batches without the caller having to filter
     * afterwards.
     */
    @Query("""
            SELECT b
              FROM StockBatch b, StockBatchBalance bb
             WHERE b.orgId           = :orgId
               AND b.itemId          = :itemId
               AND bb.orgId          = :orgId
               AND bb.batchId        = b.id
               AND bb.warehouseId    = :warehouseId
               AND bb.quantityOnHand > 0
               AND b.active          = true
               AND b.isDeleted       = false
             ORDER BY b.expiryDate ASC NULLS LAST, b.createdAt ASC
            """)
    List<StockBatch> findFefoBatches(
            @Param("orgId") UUID orgId,
            @Param("itemId") UUID itemId,
            @Param("warehouseId") UUID warehouseId);

    /**
     * All batches for an item regardless of warehouse or stock level.
     * Used by the item detail screen to show "every batch ever
     * received, with current on-hand".
     */
    List<StockBatch> findByOrgIdAndItemIdAndIsDeletedFalseOrderByExpiryDateAsc(
            UUID orgId, UUID itemId);
}
