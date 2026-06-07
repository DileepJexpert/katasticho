package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "qc_inspection_result")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class QcInspectionResult extends BaseEntity {

    @Column(name = "inspection_id", nullable = false, insertable = false, updatable = false)
    private UUID inspectionId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "inspection_id", nullable = false)
    @JsonIgnore
    private QcInspection inspection;

    @Column(name = "parameter_id", nullable = false)
    private UUID parameterId;

    @Column(name = "measured_value")
    private String measuredValue;

    @Column(name = "numeric_value")
    private BigDecimal numericValue;

    @Column(name = "is_passed")
    private Boolean isPassed;

    private String notes;
}
