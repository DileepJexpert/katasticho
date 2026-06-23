package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.StockReceipt;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockReceiptRepository extends JpaRepository<StockReceipt, UUID> {

    Optional<StockReceipt> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<StockReceipt> findByOrgIdAndIsDeletedFalseOrderByReceiptDateDesc(UUID orgId, Pageable pageable);

    Page<StockReceipt> findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByReceiptDateDesc(
            UUID orgId, UUID supplierId, Pageable pageable);

    /**
     * True if any RECEIVED, non-deleted GRN references this PO — i.e. stock has
     * already been posted for this PO via the GRN path. DRAFT GRNs are
     * deliberately NOT counted: an abandoned draft hasn't booked anything, so a
     * bill following it must still post the PURCHASE movement.
     *
     * <p>Drives the per-line P2P guard in
     * {@code PurchaseBillService.recordStockForBill}.
     */
    @Query("SELECT (COUNT(r) > 0) FROM StockReceipt r " +
           "WHERE r.orgId = :orgId AND r.purchaseOrderId = :poId " +
           "AND r.isDeleted = false AND r.status = 'RECEIVED'")
    boolean existsActiveReceiptForPurchaseOrder(@Param("orgId") UUID orgId,
                                                 @Param("poId") UUID poId);
}
