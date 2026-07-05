package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.StockCount;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockCountRepository extends JpaRepository<StockCount, UUID> {

    Optional<StockCount> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Pessimistic-write variant to serialise concurrent stock-count post. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from StockCount s where s.id = :id and s.orgId = :orgId and s.isDeleted = false")
    Optional<StockCount> findByIdAndOrgIdForUpdate(@org.springframework.data.repository.query.Param("id") UUID id,
                                                   @org.springframework.data.repository.query.Param("orgId") UUID orgId);

    Page<StockCount> findByOrgIdAndIsDeletedFalseOrderByCountDateDesc(UUID orgId, Pageable pageable);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(sc.countNumber, LENGTH(:prefix) + 2) AS int)), 0) + 1 " +
            "FROM StockCount sc WHERE sc.orgId = :orgId AND sc.countNumber LIKE CONCAT(:prefix, '-%')")
    int nextSequence(UUID orgId, String prefix);
}
