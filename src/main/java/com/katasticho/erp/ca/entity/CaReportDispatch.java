package com.katasticho.erp.ca.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.*;

@Entity
@Table(name = "ca_report_dispatch")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CaReportDispatch {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "ca_client_link_id")
    private UUID caClientLinkId;

    @Column(name = "client_org_id")
    private UUID clientOrgId;

    @Column(name = "dispatched_by")
    private UUID dispatchedBy;

    @Column(name = "period_label", nullable = false, length = 20)
    private String periodLabel;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "report_types", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<String> reportTypes = new ArrayList<>();

    @Column(name = "sent_via", nullable = false, length = 20)
    @Builder.Default
    private String sentVia = "EMAIL";

    @Column(name = "sent_to_email")
    private String sentToEmail;

    @Column(name = "sent_to_phone", length = 20)
    private String sentToPhone;

    @Column(name = "ai_commentary", nullable = false)
    @Builder.Default
    private boolean aiCommentary = false;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "report_urls", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, Object> reportUrls = new HashMap<>();

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "QUEUED";

    @Column(name = "sent_at")
    private Instant sentAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
    }
}
