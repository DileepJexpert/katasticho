package com.katasticho.erp.expense.reimbursement.repository;

import com.katasticho.erp.expense.reimbursement.entity.EmployeeReimbursementAdvanceAllocation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface EmployeeReimbursementAdvanceAllocationRepository extends JpaRepository<EmployeeReimbursementAdvanceAllocation, UUID> {
    boolean existsByReimbursementIdAndAdvanceId(UUID reimbursementId, UUID advanceId);
}
