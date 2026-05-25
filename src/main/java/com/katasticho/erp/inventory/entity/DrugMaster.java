package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "drug_master")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DrugMaster {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "brand_name", nullable = false)
    private String brandName;

    @Column(name = "generic_name")
    private String genericName;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "salt_id")
    private SaltMaster salt;

    @Column(name = "salt_composition", columnDefinition = "TEXT")
    private String saltComposition;

    @Column(length = 255)
    private String manufacturer;

    @Column(name = "hsn_code", length = 10)
    @Builder.Default
    private String hsnCode = "3004";

    @Column(name = "gst_rate", precision = 5, scale = 2)
    @Builder.Default
    private BigDecimal gstRate = BigDecimal.valueOf(12);

    @Column(name = "drug_schedule", length = 20)
    @Builder.Default
    private String drugSchedule = "GENERAL";

    @Column(name = "dosage_form", length = 50)
    private String dosageForm;

    @Column(name = "pack_size", length = 50)
    private String packSize;

    @Column(precision = 15, scale = 2)
    private BigDecimal mrp;

    @Column(name = "prescription_required", nullable = false)
    @Builder.Default
    private boolean prescriptionRequired = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
