package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PurchaseOrderLineRepository extends JpaRepository<PurchaseOrderLine, UUID> {

    List<PurchaseOrderLine> findByPoId(UUID poId);

    void deleteByPoId(UUID poId);
}
