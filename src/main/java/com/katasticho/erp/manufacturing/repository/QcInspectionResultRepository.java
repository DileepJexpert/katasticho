package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.QcInspectionResult;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface QcInspectionResultRepository extends JpaRepository<QcInspectionResult, UUID> {

    List<QcInspectionResult> findByInspectionIdAndIsDeletedFalse(UUID inspectionId);
}
