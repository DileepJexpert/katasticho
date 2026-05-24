package com.katasticho.erp.pharma.repository;

import com.katasticho.erp.pharma.entity.PrescriptionRecordItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface PrescriptionRecordItemRepository extends JpaRepository<PrescriptionRecordItem, UUID> {
}
