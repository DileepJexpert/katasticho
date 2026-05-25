package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.GenericSubstitution;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface GenericSubstitutionRepository extends JpaRepository<GenericSubstitution, UUID> {
    List<GenericSubstitution> findByDrugMasterIdAndActiveTrueOrderByEstimatedSavingsDesc(UUID drugMasterId);
}
