package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.VanStockBalance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VanStockBalanceRepository extends JpaRepository<VanStockBalance, UUID> {

    List<VanStockBalance> findByOrgIdAndVanId(UUID orgId, UUID vanId);

    Optional<VanStockBalance> findByOrgIdAndVanIdAndItemId(UUID orgId, UUID vanId, UUID itemId);

    Optional<VanStockBalance> findByOrgIdAndVanIdAndItemIdAndBatchId(UUID orgId, UUID vanId, UUID itemId, UUID batchId);

    /** The null-batch grain (its own row under the COALESCE(batch_id, zero-uuid)
     *  unique index). A null-batch lookup must target ONLY this row — the plain
     *  findByOrgIdAndVanIdAndItemId matched every batch row and blew up (500) once
     *  a van held the item in two batches. */
    Optional<VanStockBalance> findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(UUID orgId, UUID vanId, UUID itemId);
}
