package com.katasticho.erp.accounting.entity;

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

/**
 * One budgeted account for one fiscal year (annual amount). The variance
 * report pro-rates the annual amount over the compared window.
 */
@Entity
@Table(name = "budget_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BudgetLine extends BaseEntity {

    /** FY start year: 2026 = FY 2026-27 (April–March). */
    @Column(name = "fiscal_year", nullable = false)
    private int fiscalYear;

    @Column(name = "account_code", nullable = false, length = 20)
    private String accountCode;

    @Column(name = "annual_amount", nullable = false)
    @Builder.Default
    private BigDecimal annualAmount = BigDecimal.ZERO;

    @Column(length = 255)
    private String notes;
}
