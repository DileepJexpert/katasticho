package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.EmployeeDocument;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeDocumentRepository extends JpaRepository<EmployeeDocument, UUID> {

    Optional<EmployeeDocument> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<EmployeeDocument> findByOrgIdAndEmployeeUserIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, UUID employeeUserId);

    List<EmployeeDocument> findByOrgIdAndExpiryDateLessThanEqualAndIsDeletedFalseOrderByExpiryDateAsc(
            UUID orgId, LocalDate cutoff);
}
