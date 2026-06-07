package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.JobWorkOrderLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface JobWorkOrderLineRepository extends JpaRepository<JobWorkOrderLine, UUID> {

    List<JobWorkOrderLine> findByJobWorkOrderIdAndIsDeletedFalse(UUID jobWorkOrderId);
}
