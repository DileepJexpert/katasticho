package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Entity
@Table(name = "rack_location")
@Getter
@Setter
@NoArgsConstructor
public class RackLocation extends BaseEntity {

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(nullable = false, length = 50)
    private String code;

    @Column(length = 100)
    private String name;

    @Column(length = 50)
    private String zone;

    @Column(length = 50)
    private String aisle;

    @Column(length = 50)
    private String shelf;

    @Column(length = 50)
    private String bin;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;
}
