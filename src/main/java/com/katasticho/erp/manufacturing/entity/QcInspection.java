package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "qc_inspection")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class QcInspection extends BaseEntity {

    @Column(name = "inspection_number", nullable = false, length = 30)
    private String inspectionNumber;

    @Column(name = "template_id")
    private UUID templateId;

    @Column(name = "inspection_type", nullable = false, length = 30)
    private String inspectionType;

    @Column(name = "reference_type", length = 30)
    private String referenceType;

    @Column(name = "reference_id")
    private UUID referenceId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(name = "inspected_qty", nullable = false)
    private BigDecimal inspectedQty;

    @Column(name = "accepted_qty", nullable = false)
    private BigDecimal acceptedQty;

    @Column(name = "rejected_qty", nullable = false)
    private BigDecimal rejectedQty;

    @Column(length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "inspector_id")
    private UUID inspectorId;

    /** Resolved display names (not persisted) — populated on inspection responses. */
    @Transient
    private String itemName;
    @Transient
    private String inspectorName;
    @Transient
    private String batchNumber;
    @Transient
    private String referenceLabel;

    @Column(name = "inspected_at")
    private Instant inspectedAt;

    private String notes;

    /** ACCEPT | REJECT | HOLD — null until a disposition is recorded. */
    @Column(length = 10)
    private String disposition;

    @Column(name = "hold_qty")
    private BigDecimal holdQty;

    @Column(name = "quarantine_zone_id")
    private UUID quarantineZoneId;

    @Column(name = "disposition_notes")
    private String dispositionNotes;

    @Column(name = "disposition_at")
    private Instant dispositionAt;

    @Column(name = "disposition_by")
    private UUID dispositionBy;

    @OneToMany(mappedBy = "inspection", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<QcInspectionResult> results = new ArrayList<>();
}
