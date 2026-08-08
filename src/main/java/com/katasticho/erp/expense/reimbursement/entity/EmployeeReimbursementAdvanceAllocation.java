package com.katasticho.erp.expense.reimbursement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "employee_reimbursement_advance_allocation")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmployeeReimbursementAdvanceAllocation extends BaseEntity {
    @Column(name = "reimbursement_id", nullable = false) private UUID reimbursementId;
    @Column(name = "advance_id", nullable = false) private UUID advanceId;
    @Column(nullable = false, precision = 15, scale = 2) private BigDecimal amount;
}
