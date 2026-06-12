package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "mrp_run")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MrpRun extends BaseEntity {

    @Column(name = "run_date", nullable = false)
    private LocalDate runDate;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "RUNNING";  // RUNNING | COMPLETED | FAILED

    @Column(name = "horizon_days", nullable = false)
    @Builder.Default
    private int horizonDays = 90;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "mrpRun", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<MrpDemand> demands = new ArrayList<>();

    @OneToMany(mappedBy = "mrpRun", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<MrpSupply> supplies = new ArrayList<>();

    @OneToMany(mappedBy = "mrpRun", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<PlannedOrder> plannedOrders = new ArrayList<>();
}
