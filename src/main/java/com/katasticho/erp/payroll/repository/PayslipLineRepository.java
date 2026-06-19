package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.PayslipLine;
import com.katasticho.erp.tax.dto.SalaryTdsLineRow;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface PayslipLineRepository extends JpaRepository<PayslipLine, UUID> {

    /**
     * All payslip lines for the given payroll runs, flattened with their
     * salary-component code/type. Powers salary-TDS aggregation (Form 24Q / 16).
     */
    @Query("""
            SELECT new com.katasticho.erp.tax.dto.SalaryTdsLineRow(
                pl.payslip.employeeId, sc.code, pl.componentType, pl.amount, pl.payslip.payrollRunId)
            FROM PayslipLine pl
            JOIN pl.salaryComponent sc
            WHERE pl.orgId = :orgId AND pl.payslip.payrollRunId IN :runIds
            """)
    List<SalaryTdsLineRow> findLineRowsForRuns(UUID orgId, Collection<UUID> runIds);
}
