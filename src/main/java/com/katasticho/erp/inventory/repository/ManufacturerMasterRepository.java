package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.ManufacturerMaster;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ManufacturerMasterRepository extends JpaRepository<ManufacturerMaster, UUID> {
    List<ManufacturerMaster> findByNameContainingIgnoreCaseAndActiveTrueOrderByNameAsc(String query, Pageable pageable);
    Optional<ManufacturerMaster> findByNameIgnoreCaseAndActiveTrue(String name);
}
