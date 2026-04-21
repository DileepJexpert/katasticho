package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.UomConversion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UomConversionRepository extends JpaRepository<UomConversion, UUID> {

    /**
     * Per-item override lookup. Returns the conversion row whose
     * {@code item_id} matches, if one exists.
     */
    @Query("""
            SELECT c FROM UomConversion c
            WHERE c.orgId      = :orgId
              AND c.itemId     = :itemId
              AND c.fromUomId  = :fromUomId
              AND c.toUomId    = :toUomId
              AND c.isDeleted  = false
            """)
    Optional<UomConversion> findPerItem(
            @Param("orgId") UUID orgId,
            @Param("itemId") UUID itemId,
            @Param("fromUomId") UUID fromUomId,
            @Param("toUomId") UUID toUomId);

    /**
     * Org-wide conversion lookup. {@code item_id IS NULL}.
     */
    @Query("""
            SELECT c FROM UomConversion c
            WHERE c.orgId      = :orgId
              AND c.itemId     IS NULL
              AND c.fromUomId  = :fromUomId
              AND c.toUomId    = :toUomId
              AND c.isDeleted  = false
            """)
    Optional<UomConversion> findOrgWide(
            @Param("orgId") UUID orgId,
            @Param("fromUomId") UUID fromUomId,
            @Param("toUomId") UUID toUomId);

    List<UomConversion> findByOrgIdAndIsDeletedFalse(UUID orgId);

    List<UomConversion> findByOrgIdAndItemIdAndIsDeletedFalse(UUID orgId, UUID itemId);
}
