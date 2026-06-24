package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.PurchaseOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PurchaseOrderRepository extends JpaRepository<PurchaseOrder, UUID> {

    List<PurchaseOrder> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<PurchaseOrder> findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, UUID supplierId);

    Optional<PurchaseOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);

    /**
     * True when a non-deleted PO in one of the given open statuses (e.g.
     * DRAFT / SENT) references the item on at least one of its lines. Powers
     * the agentic-replenishment dedupe — when the planner has already drafted
     * a real PO, don't pile a second suggestion on top.
     */
    @Query("""
            SELECT COUNT(pol) > 0 FROM PurchaseOrderLine pol, PurchaseOrder po
            WHERE pol.poId = po.id
              AND pol.itemId = :itemId
              AND po.orgId = :orgId
              AND po.isDeleted = false
              AND po.status IN :statuses
            """)
    boolean existsOpenForItem(@Param("orgId") UUID orgId,
                              @Param("itemId") UUID itemId,
                              @Param("statuses") Collection<String> statuses);
}
