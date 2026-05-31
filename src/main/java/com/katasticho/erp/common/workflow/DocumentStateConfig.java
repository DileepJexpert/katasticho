package com.katasticho.erp.common.workflow;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "document_state_config",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_document_state_config_transition",
                columnNames = {"org_id", "document_type", "from_state", "to_state"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DocumentStateConfig extends BaseEntity {

    @Column(name = "document_type", nullable = false, length = 50)
    private String documentType;

    @Column(name = "from_state", nullable = false, length = 30)
    private String fromState;

    @Column(name = "to_state", nullable = false, length = 30)
    private String toState;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "allowed_roles", nullable = false, columnDefinition = "text[]")
    private String[] allowedRoles;

    @Column(name = "requires_approval", nullable = false)
    @Builder.Default
    private boolean requiresApproval = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
