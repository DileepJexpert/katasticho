package com.katasticho.erp.tax.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "tax_group_rate")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class TaxGroupRate {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "tax_group_id", nullable = false)
    private UUID taxGroupId;

    @Column(name = "tax_rate_id", nullable = false)
    private UUID taxRateId;
}
