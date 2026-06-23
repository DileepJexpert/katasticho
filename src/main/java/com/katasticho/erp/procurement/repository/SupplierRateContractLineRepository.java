package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.SupplierRateContractLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SupplierRateContractLineRepository
        extends JpaRepository<SupplierRateContractLine, UUID> {

    List<SupplierRateContractLine> findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID contractId);

    /**
     * Resolve the active negotiated unit price for (org, supplier, item) on a
     * given as-of date. Returns at most one row — the activate() guard plus the
     * DB-level {@code uq_src_active_line} partial unique index together
     * enforce one-active-at-a-time across application-level races.
     *
     * <p>{@code asOf} narrows on {@code valid_from <= asOf AND
     * (valid_until IS NULL OR valid_until >= asOf)} so an ACTIVE contract whose
     * dates have lapsed but whose status hasn't been swept yet does NOT price
     * a fresh PO. Pass {@code LocalDate.now(clock)} from the caller.
     */
    @Query("""
        SELECT l FROM SupplierRateContractLine l
        WHERE l.orgId = :orgId
          AND l.itemId = :itemId
          AND l.isDeleted = false
          AND l.activeLine = true
          AND l.supplierContactId = :supplierContactId
          AND l.supplierRateContractId IN (
              SELECT c.id FROM SupplierRateContract c
              WHERE c.orgId = :orgId
                AND c.supplierContactId = :supplierContactId
                AND c.status = 'ACTIVE'
                AND c.isDeleted = false
                AND (c.validFrom IS NULL OR c.validFrom <= :asOf)
                AND (c.validUntil IS NULL OR c.validUntil >= :asOf))
    """)
    Optional<SupplierRateContractLine> findActiveLine(
            @Param("orgId") UUID orgId,
            @Param("supplierContactId") UUID supplierContactId,
            @Param("itemId") UUID itemId,
            @Param("asOf") LocalDate asOf);
}
