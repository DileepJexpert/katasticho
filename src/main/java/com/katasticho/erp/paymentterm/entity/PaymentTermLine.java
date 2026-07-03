package com.katasticho.erp.paymentterm.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * One line of a {@link PaymentTerm}. {@code valueType}:
 * <ul>
 *   <li>{@code PERCENT} — {@code value} percent of the invoice total;</li>
 *   <li>{@code BALANCE} — "the remainder" (value ignored). Must be the last line.</li>
 * </ul>
 * The instalment is due {@code daysOffset} days after the invoice date.
 */
@Entity
@Table(name = "payment_term_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentTermLine extends BaseEntity {

    @Column(name = "payment_term_id", nullable = false)
    private UUID paymentTermId;

    @Column(nullable = false)
    @Builder.Default
    private int seq = 0;

    @Column(name = "value_type", nullable = false, length = 10)
    @Builder.Default
    private String valueType = "PERCENT";

    @Column(nullable = false, precision = 9, scale = 4)
    @Builder.Default
    private BigDecimal value = BigDecimal.ZERO;

    @Column(name = "days_offset", nullable = false)
    @Builder.Default
    private int daysOffset = 0;
}
