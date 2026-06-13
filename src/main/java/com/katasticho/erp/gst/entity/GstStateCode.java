package com.katasticho.erp.gst.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * Official GST/TIN state code — the first two digits of every GSTIN.
 *
 * Platform-level reference data (no org_id, no BaseEntity): these are universal
 * facts shared across all tenants, mirroring {@code hsn_gst_master}.
 */
@Entity
@Table(name = "gst_state_code")
@Getter
@Setter
@NoArgsConstructor
public class GstStateCode {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Two-digit GST state code, e.g. "27" for Maharashtra. */
    @Column(nullable = false, unique = true, length = 2)
    private String code;

    @Column(name = "state_name", nullable = false, length = 60)
    private String stateName;

    /** Short alpha code, e.g. "MH". */
    @Column(name = "alpha_code", length = 3)
    private String alphaCode;

    @Column(name = "is_union_territory", nullable = false)
    private boolean unionTerritory = false;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false,
            insertable = false, columnDefinition = "TIMESTAMPTZ DEFAULT NOW()")
    private Instant createdAt;
}
