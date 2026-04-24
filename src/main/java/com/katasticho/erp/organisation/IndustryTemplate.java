package com.katasticho.erp.organisation;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "industry_template")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IndustryTemplate {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "business_type", nullable = false, length = 20)
    private String businessType;

    @Column(name = "industry_code", nullable = false, unique = true, length = 30)
    private String industryCode;

    @Column(name = "industry_label", nullable = false, length = 50)
    private String industryLabel;

    @Column(name = "industry_icon", length = 10)
    private String industryIcon;

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private int sortOrder = 0;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
