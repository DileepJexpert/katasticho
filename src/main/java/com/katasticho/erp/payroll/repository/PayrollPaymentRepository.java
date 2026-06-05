package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.PayrollPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PayrollPaymentRepository extends JpaRepository<PayrollPayment, UUID> {

    List<PayrollPayment> findByOrgIdAndPayrollRunId(UUID orgId, UUID payrollRunId);
}
