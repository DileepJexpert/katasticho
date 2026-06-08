package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.Workstation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WorkstationRepository extends JpaRepository<Workstation, UUID> {

    List<Workstation> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    Optional<Workstation> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
}
