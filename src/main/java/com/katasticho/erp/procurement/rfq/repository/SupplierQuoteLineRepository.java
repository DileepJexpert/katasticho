package com.katasticho.erp.procurement.rfq.repository;

import com.katasticho.erp.procurement.rfq.entity.SupplierQuoteLine;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface SupplierQuoteLineRepository extends JpaRepository<SupplierQuoteLine, UUID> {

    List<SupplierQuoteLine> findBySupplierQuoteIdAndIsDeletedFalseOrderByCreatedAtAsc(UUID supplierQuoteId);

    List<SupplierQuoteLine> findBySupplierQuoteIdInAndIsDeletedFalse(List<UUID> supplierQuoteIds);
}
