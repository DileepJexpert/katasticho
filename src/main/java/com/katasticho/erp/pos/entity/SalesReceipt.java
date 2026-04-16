package com.katasticho.erp.pos.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Point-of-sale sales receipt — one-shot transaction, no DRAFT state.
 * Created as COMPLETED immediately with journal entry and stock deductions.
 */
@Entity
@Table(name = "sales_receipt")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalesReceipt extends BaseEntity {

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "receipt_number", nullable = false, length = 30)
    private String receiptNumber;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "receipt_date", nullable = false)
    private LocalDate receiptDate;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "tax_amount", nullable = false)
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal total = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_mode", nullable = false, length = 20)
    private PaymentMode paymentMode;

    @Column(name = "paid_through_id")
    private UUID paidThroughId;

    @Column(name = "amount_received", nullable = false)
    @Builder.Default
    private BigDecimal amountReceived = BigDecimal.ZERO;

    @Column(name = "change_returned", nullable = false)
    @Builder.Default
    private BigDecimal changeReturned = BigDecimal.ZERO;

    @Column(name = "upi_reference", length = 50)
    private String upiReference;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(length = 500)
    private String notes;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @OneToMany(mappedBy = "receipt", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("lineNumber ASC")
    @Builder.Default
    private List<SalesReceiptLine> lines = new ArrayList<>();

    public void addLine(SalesReceiptLine line) {
        line.setReceipt(this);
        this.lines.add(line);
    }
}
