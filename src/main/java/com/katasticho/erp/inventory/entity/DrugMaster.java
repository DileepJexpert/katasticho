package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "drug_master")
@Getter
@Setter
@NoArgsConstructor
public class DrugMaster {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "brand_name", nullable = false)
    private String brandName;

    @Column(name = "generic_name")
    private String genericName;

    @Column(name = "salt_id")
    private UUID saltId;

    @Column(name = "salt_composition", columnDefinition = "TEXT")
    private String saltComposition;

    @Column(name = "manufacturer")
    private String manufacturer;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

    @Column(name = "gst_rate", precision = 5, scale = 2)
    private BigDecimal gstRate;

    @Column(name = "drug_schedule", length = 10)
    private String drugSchedule;

    @Column(name = "dosage_form", length = 50)
    private String dosageForm;

    @Column(name = "pack_size", length = 50)
    private String packSize;

    @Column(name = "mrp", precision = 15, scale = 2)
    private BigDecimal mrp;

    @Column(name = "prescription_required", nullable = false)
    private boolean prescriptionRequired;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false,
            insertable = false, columnDefinition = "TIMESTAMP DEFAULT NOW()")
    private Instant createdAt;
}
