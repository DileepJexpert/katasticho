package com.katasticho.erp.expense.reimbursement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "employee_expense_advance")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmployeeExpenseAdvance extends BaseEntity {
    @Column(name = "employee_id", nullable = false) private UUID employeeId;
    @Column(name = "advance_date", nullable = false) private LocalDate advanceDate;
    @Column(nullable = false, precision = 15, scale = 2) private BigDecimal amount;
    @Column(name = "settled_amount", nullable = false, precision = 15, scale = 2) @Builder.Default private BigDecimal settledAmount = BigDecimal.ZERO;
    @Column(nullable = false, length = 20) @Builder.Default private String status = "OPEN";
    @Column(name = "paid_through_id", nullable = false) private UUID paidThroughId;
    @Column(name = "journal_entry_id", nullable = false) private UUID journalEntryId;
    @Column(length = 1000) private String notes;
}
