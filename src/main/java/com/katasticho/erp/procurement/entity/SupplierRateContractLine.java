package com.katasticho.erp.procurement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "supplier_rate_contract_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupplierRateContractLine extends BaseEntity {

    @Column(name = "supplier_rate_contract_id", nullable = false)
    private UUID supplierRateContractId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "unit_price", nullable = false, precision = 15, scale = 2)
    private BigDecimal unitPrice;

    @Column(name = "min_order_qty", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal minOrderQty = BigDecimal.ZERO;

    @Column(length = 500)
    private String notes;

    /**
     * Denormalised from the parent {@code supplier_rate_contract.supplier_contact_id}.
     * Required for the DB-level partial unique index {@code uq_src_active_line}
     * that enforces one active line per (org, supplier, item) — Postgres can't
     * reference a parent row in a partial index predicate.
     */
    @Column(name = "supplier_contact_id")
    private UUID supplierContactId;

    /**
     * True when the parent contract is currently ACTIVE. Flipped to true on
     * {@code activate()} and back to false on {@code expire()/cancel()}. The
     * DB unique index keys off this — only active lines are uniqueness-constrained.
     */
    @Column(name = "is_active_line", nullable = false)
    @Builder.Default
    private boolean activeLine = false;
}
