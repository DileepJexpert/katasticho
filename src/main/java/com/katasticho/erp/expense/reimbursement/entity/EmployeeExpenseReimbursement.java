package com.katasticho.erp.expense.reimbursement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "employee_expense_reimbursement")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmployeeExpenseReimbursement extends BaseEntity {
    @Column(name = "employee_id", nullable = false) private UUID employeeId;
    @Column(name = "expense_id") private UUID expenseId;
    @Column(name = "expense_date", nullable = false) private LocalDate expenseDate;
    @Column(name = "account_id", nullable = false) private UUID accountId;
    @Column(length = 80) private String category;
    @Column(nullable = false, length = 500) private String description;
    @Column(nullable = false, precision = 15, scale = 2) private BigDecimal amount;
    @Column(nullable = false, length = 20) @Builder.Default private String status = "SUBMITTED";
    @Column(name = "advance_applied", nullable = false, precision = 15, scale = 2) @Builder.Default private BigDecimal advanceApplied = BigDecimal.ZERO;
    @Column(name = "payable_amount", nullable = false, precision = 15, scale = 2) @Builder.Default private BigDecimal payableAmount = BigDecimal.ZERO;
    @Column(name = "receipt_url", length = 1000) private String receiptUrl;
    @Column(length = 1000) private String notes;
    @Column(name = "approved_by") private UUID approvedBy;
    @Column(name = "approved_at") private Instant approvedAt;
    @Column(name = "rejected_by") private UUID rejectedBy;
    @Column(name = "rejected_at") private Instant rejectedAt;
    @Column(name = "rejection_reason", length = 1000) private String rejectionReason;
    @Column(name = "paid_through_id") private UUID paidThroughId;
    @Column(name = "paid_amount", nullable = false, precision = 15, scale = 2) @Builder.Default private BigDecimal paidAmount = BigDecimal.ZERO;
    @Column(name = "paid_at") private Instant paidAt;
    @Column(name = "payment_journal_entry_id") private UUID paymentJournalEntryId;
    @Column(name = "settlement_journal_entry_id") private UUID settlementJournalEntryId;
}
