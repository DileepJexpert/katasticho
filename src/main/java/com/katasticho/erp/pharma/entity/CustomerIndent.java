package com.katasticho.erp.pharma.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "customer_indent")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CustomerIndent extends BaseEntity {

    @Column(name = "indent_number", nullable = false, length = 30)
    private String indentNumber;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "customer_name", nullable = false)
    private String customerName;

    @Column(name = "customer_phone", length = 30)
    private String customerPhone;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "item_name", nullable = false)
    private String itemName;

    @Column(name = "item_sku", length = 80)
    private String itemSku;

    @Column(nullable = false, precision = 19, scale = 4)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ONE;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "REQUESTED";

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String source = "MANUAL";

    @Column(name = "needed_by")
    private LocalDate neededBy;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "notified_at")
    private Instant notifiedAt;

    @Column(name = "fulfilled_at")
    private Instant fulfilledAt;
}
