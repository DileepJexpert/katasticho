package com.katasticho.erp.procurement.rfq.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "rfq_supplier")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RfqSupplier extends BaseEntity {

    @Column(name = "rfq_id", nullable = false)
    private UUID rfqId;

    @Column(name = "supplier_contact_id", nullable = false)
    private UUID supplierContactId;
}
