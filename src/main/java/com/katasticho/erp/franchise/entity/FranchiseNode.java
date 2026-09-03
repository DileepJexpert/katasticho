package com.katasticho.erp.franchise.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "franchise_node")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FranchiseNode extends BaseEntity {

    @Column(name = "node_code", nullable = false, length = 50)
    private String nodeCode;

    @Column(name = "node_name", nullable = false, length = 150)
    private String nodeName;

    @Column(name = "node_type", nullable = false, length = 30)
    @Builder.Default
    private String nodeType = "FOFO"; // COCO, FOFO, FICO

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "contact_email", length = 100)
    private String contactEmail;

    @Column(length = 30)
    private String phone;

    @Column(length = 100)
    private String city;

    @Column(name = "state_code", length = 5)
    private String stateCode;

    @Column(name = "royalty_rate_percent", precision = 5, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal royaltyRatePercent = new BigDecimal("5.00");

    @Column(name = "fixed_monthly_fee", precision = 15, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal fixedMonthlyFee = BigDecimal.ZERO;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "last_sync_at")
    private OffsetDateTime lastSyncAt;
}