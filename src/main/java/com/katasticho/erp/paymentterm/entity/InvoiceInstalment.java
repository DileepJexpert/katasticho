package com.katasticho.erp.paymentterm.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * A materialised instalment on an invoice: {@code amount} due on {@code dueDate}.
 * Paid/overdue status is NOT stored — it is derived at read time from the
 * invoice's existing {@code amountPaid} via an oldest-first waterfall, so no
 * payment ever targets a dated sub-balance and the payment engine is untouched.
 */
@Entity
@Table(name = "invoice_instalment")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InvoiceInstalment extends BaseEntity {

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "payment_term_id")
    private UUID paymentTermId;

    @Column(nullable = false)
    @Builder.Default
    private int seq = 0;

    @Column(nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal amount = BigDecimal.ZERO;

    @Column(name = "due_date", nullable = false)
    private LocalDate dueDate;
}
