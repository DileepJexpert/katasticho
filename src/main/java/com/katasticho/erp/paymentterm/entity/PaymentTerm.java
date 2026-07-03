package com.katasticho.erp.paymentterm.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * A named payment schedule (Odoo "payment terms"). Its {@link PaymentTermLine}s
 * split an invoice's total into instalments — each a percent-of-total (or a
 * trailing BALANCE line) due {@code daysOffset} days after the invoice date.
 * Applying a term to an invoice materialises {@code invoice_instalment} rows.
 */
@Entity
@Table(name = "payment_term")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentTerm extends BaseEntity {

    @Column(nullable = false, length = 120)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "is_default", nullable = false)
    @Builder.Default
    private boolean isDefault = false;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;
}
