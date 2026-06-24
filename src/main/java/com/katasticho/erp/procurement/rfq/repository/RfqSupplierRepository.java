package com.katasticho.erp.procurement.rfq.repository;

import com.katasticho.erp.procurement.rfq.entity.RfqSupplier;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface RfqSupplierRepository extends JpaRepository<RfqSupplier, UUID> {

    List<RfqSupplier> findByRfqIdAndIsDeletedFalse(UUID rfqId);
}
