package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PurchaseOrderLineRepository extends JpaRepository<PurchaseOrderLine, UUID> {

    List<PurchaseOrderLine> findByPoId(UUID poId);

    void deleteByPoId(UUID poId);

    /**
     * PO lines for a given item that still have pending qty
     * ({@code quantity > receivedQuantity}) on a non-deleted PO belonging to
     * the org. Powers the ATP "open inflow" computation — caller filters by
     * header status / warehouse in Java.
     */
    @Query("""
            SELECT pol FROM PurchaseOrderLine pol, PurchaseOrder po
            WHERE pol.poId = po.id
              AND pol.itemId = :itemId
              AND po.orgId = :orgId
              AND po.isDeleted = false
              AND pol.quantity > pol.receivedQuantity
            """)
    List<PurchaseOrderLine> findOpenForItem(@Param("orgId") UUID orgId, @Param("itemId") UUID itemId);
}
