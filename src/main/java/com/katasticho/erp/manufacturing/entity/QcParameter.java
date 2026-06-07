package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "qc_parameter")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class QcParameter extends BaseEntity {

    @Column(name = "template_id", nullable = false, insertable = false, updatable = false)
    private UUID templateId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "template_id", nullable = false)
    @JsonIgnore
    private QcTemplate template;

    @Column(nullable = false)
    private String name;

    private String description;

    @Column(name = "parameter_type", length = 20)
    @Builder.Default
    private String parameterType = "NUMERIC";

    private String unit;

    @Column(name = "min_value")
    private BigDecimal minValue;

    @Column(name = "max_value")
    private BigDecimal maxValue;

    @Column(name = "acceptable_values")
    private String acceptableValues;

    @Column(name = "is_mandatory", nullable = false)
    @Builder.Default
    private boolean isMandatory = true;

    @Column(name = "sequence_number", nullable = false)
    @Builder.Default
    private int sequenceNumber = 1;
}
