package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.WorkOrderLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WorkOrderLineRepository extends JpaRepository<WorkOrderLine, UUID> {

    List<WorkOrderLine> findByWorkOrderIdAndIsDeletedFalse(UUID workOrderId);
}
