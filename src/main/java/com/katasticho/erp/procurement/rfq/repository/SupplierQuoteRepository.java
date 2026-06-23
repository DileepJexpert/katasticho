package com.katasticho.erp.procurement.rfq.repository;

import com.katasticho.erp.procurement.rfq.entity.SupplierQuote;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SupplierQuoteRepository extends JpaRepository<SupplierQuote, UUID> {

    Optional<SupplierQuote> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<SupplierQuote> findByRfqIdAndIsDeletedFalseOrderByTotalAmountAsc(UUID rfqId);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
