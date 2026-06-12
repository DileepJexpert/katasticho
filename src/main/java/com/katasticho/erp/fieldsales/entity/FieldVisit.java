package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "field_visit")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FieldVisit {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "route_execution_id", nullable = false)
    private UUID routeExecutionId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "beat_id")
    private UUID beatId;

    @Column(name = "sequence_number")
    private Integer sequenceNumber;

    @Column(length = 20)
    @Builder.Default
    private String status = "PLANNED";

    @Column(name = "check_in_time")
    private Instant checkInTime;

    @Column(name = "check_out_time")
    private Instant checkOutTime;

    @Column(name = "check_in_latitude")
    private BigDecimal checkInLatitude;

    @Column(name = "check_in_longitude")
    private BigDecimal checkInLongitude;

    @Column(name = "check_out_latitude")
    private BigDecimal checkOutLatitude;

    @Column(name = "check_out_longitude")
    private BigDecimal checkOutLongitude;

    /** Geofence result at check-in; null when the beat customer has no stored coordinates. */
    @Column(name = "geo_verified")
    private Boolean geoVerified;

    @Column(name = "geo_distance_m")
    private BigDecimal geoDistanceM;

    @Column(name = "sales_order_id")
    private UUID salesOrderId;

    @Column(name = "order_value", nullable = false)
    @Builder.Default
    private BigDecimal orderValue = BigDecimal.ZERO;

    @Column(name = "collection_amount", nullable = false)
    @Builder.Default
    private BigDecimal collectionAmount = BigDecimal.ZERO;

    @Column(name = "delivery_challan_id")
    private UUID deliveryChallanId;

    @Column(name = "skip_reason", length = 200)
    private String skipReason;

    private String notes;

    @Column(name = "photo_url")
    private String photoUrl;

    /** Manager who worked jointly with the MR on this visit. */
    @Column(name = "joint_visit_user_id")
    private UUID jointVisitUserId;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
        if (this.orgId == null) {
            this.orgId = TenantContext.getCurrentOrgId();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
