package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.TransferOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface TransferOrderRepository extends JpaRepository<TransferOrder, UUID> {

    Optional<TransferOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Pessimistic-write variant to serialise concurrent ship/receive/cancel. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from TransferOrder t where t.id = :id and t.orgId = :orgId and t.isDeleted = false")
    Optional<TransferOrder> findByIdAndOrgIdForUpdate(@org.springframework.data.repository.query.Param("id") UUID id,
                                                      @org.springframework.data.repository.query.Param("orgId") UUID orgId);

    Page<TransferOrder> findByOrgIdAndIsDeletedFalseOrderByTransferDateDesc(UUID orgId, Pageable pageable);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(t.transferNumber, LENGTH(:prefix) + 2) AS int)), 0) + 1 " +
            "FROM TransferOrder t WHERE t.orgId = :orgId AND t.transferNumber LIKE CONCAT(:prefix, '-%')")
    int nextSequence(UUID orgId, String prefix);
}
