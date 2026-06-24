package com.katasticho.erp.procurement.rfq.repository;

import com.katasticho.erp.procurement.rfq.entity.RfqLine;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface RfqLineRepository extends JpaRepository<RfqLine, UUID> {

    List<RfqLine> findByRfqIdAndIsDeletedFalseOrderByCreatedAtAsc(UUID rfqId);
}
