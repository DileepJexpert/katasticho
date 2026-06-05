package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "beat")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Beat extends BaseEntity {

    @Column(nullable = false, length = 30)
    private String code;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 100)
    private String area;

    @Column(length = 100)
    private String city;

    @Column(length = 50)
    private String state;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;
}
