package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.Operation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OperationRepository extends JpaRepository<Operation, UUID> {

    List<Operation> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    Optional<Operation> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
}
