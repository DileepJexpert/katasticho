package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "qc_template")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class QcTemplate extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @Column(name = "item_id")
    private UUID itemId;

    @Column(name = "inspection_type", length = 30)
    @Builder.Default
    private String inspectionType = "INCOMING";

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;

    @OneToMany(mappedBy = "template", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<QcParameter> parameters = new ArrayList<>();
}
