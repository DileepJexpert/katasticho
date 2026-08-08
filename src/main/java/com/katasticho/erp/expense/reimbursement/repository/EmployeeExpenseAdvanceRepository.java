package com.katasticho.erp.expense.reimbursement.repository;

import com.katasticho.erp.expense.reimbursement.entity.EmployeeExpenseAdvance;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface EmployeeExpenseAdvanceRepository extends JpaRepository<EmployeeExpenseAdvance, UUID> {
    List<EmployeeExpenseAdvance> findByOrgIdAndEmployeeIdAndStatusAndIsDeletedFalseOrderByAdvanceDateAscCreatedAtAsc(UUID orgId, UUID employeeId, String status);
    Page<EmployeeExpenseAdvance> findByOrgIdAndIsDeletedFalseOrderByAdvanceDateDescCreatedAtDesc(UUID orgId, Pageable pageable);
}
