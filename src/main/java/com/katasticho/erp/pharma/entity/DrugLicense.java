package com.katasticho.erp.pharma.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "drug_licenses")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DrugLicense extends BaseEntity {

    @Column(name = "license_type", nullable = false, length = 50)
    private String licenseType;

    @Column(name = "license_number", nullable = false, length = 100)
    private String licenseNumber;

    @Column(name = "issued_by", length = 200)
    private String issuedBy;

    @Column(name = "issue_date")
    private LocalDate issueDate;

    @Column(name = "expiry_date", nullable = false)
    private LocalDate expiryDate;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
