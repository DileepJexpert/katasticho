package com.katasticho.erp.procurement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "supplier_rate_contract")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupplierRateContract extends BaseEntity {

    @Column(name = "contract_number", nullable = false, length = 30)
    private String contractNumber;

    @Column(name = "supplier_contact_id", nullable = false)
    private UUID supplierContactId;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "valid_from", nullable = false)
    private LocalDate validFrom;

    @Column(name = "valid_until")
    private LocalDate validUntil;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(columnDefinition = "TEXT")
    private String notes;
}
