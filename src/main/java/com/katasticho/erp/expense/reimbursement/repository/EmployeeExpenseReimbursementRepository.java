package com.katasticho.erp.expense.reimbursement.repository;

import com.katasticho.erp.expense.reimbursement.entity.EmployeeExpenseReimbursement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface EmployeeExpenseReimbursementRepository extends JpaRepository<EmployeeExpenseReimbursement, UUID> {
    Page<EmployeeExpenseReimbursement> findByOrgIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(UUID orgId, Pageable pageable);
    Page<EmployeeExpenseReimbursement> findByOrgIdAndStatusAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(UUID orgId, String status, Pageable pageable);
    Page<EmployeeExpenseReimbursement> findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(UUID orgId, UUID employeeId, Pageable pageable);
    java.util.Optional<EmployeeExpenseReimbursement> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
}
