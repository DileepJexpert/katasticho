package com.katasticho.erp.pharma.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "prescription_record")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PrescriptionRecord extends BaseEntity {

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "receipt_id")
    private UUID receiptId;

    @Column(name = "doctor_name", length = 200)
    private String doctorName;

    @Column(name = "doctor_reg_number", length = 100)
    private String doctorRegNumber;

    @Column(name = "prescription_number", length = 100)
    private String prescriptionNumber;

    @Column(name = "prescribed_date")
    private LocalDate prescribedDate;

    @Column(name = "valid_until")
    private LocalDate validUntil;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "prescriptionRecord", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<PrescriptionRecordItem> items = new ArrayList<>();
}
