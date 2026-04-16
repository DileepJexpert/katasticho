package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.TaxLineItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface TaxLineItemRepository extends JpaRepository<TaxLineItem, UUID> {

    List<TaxLineItem> findBySourceTypeAndSourceId(String sourceType, UUID sourceId);

    void deleteBySourceTypeAndSourceId(String sourceType, UUID sourceId);

    List<TaxLineItem> findBySourceTypeAndSourceIdAndSourceLineId(String sourceType, UUID sourceId, UUID sourceLineId);

    @Query("""
        SELECT t FROM TaxLineItem t
        WHERE t.orgId = :orgId
          AND t.sourceType = :sourceType
          AND t.taxRegime = :taxRegime
        ORDER BY t.createdAt
    """)
    List<TaxLineItem> findByOrgAndSourceTypeAndRegime(UUID orgId, String sourceType, String taxRegime);
}
