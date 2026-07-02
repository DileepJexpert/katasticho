package com.katasticho.erp.payroll.india;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * One monthly India-gratuity provision posting run, keyed uniquely by
 * (org, year, month) so re-runs and a two-replica scheduler cannot double-book.
 * The audit trail of the accrued liability period by period.
 */
@Entity
@Table(name = "india_gratuity_accrual")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IndiaGratuityAccrual extends BaseEntity {

    @Column(name = "period_year", nullable = false)
    private int periodYear;

    @Column(name = "period_month", nullable = false)
    private int periodMonth;

    @Column(name = "total_amount", nullable = false)
    private BigDecimal totalAmount;

    @Column(name = "employee_count", nullable = false)
    private int employeeCount;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;
}
