package com.katasticho.erp.organisation;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "industry_feature_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IndustryFeatureConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "industry_template_id", nullable = false)
    private UUID industryTemplateId;

    @Column(name = "sub_category_code", length = 50)
    private String subCategoryCode;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "feature_flags", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<String> featureFlags = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "uom_list", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<String> uomList = new ArrayList<>();

    @Column(name = "coa_template", nullable = false, length = 30)
    @Builder.Default
    private String coaTemplate = "INDIAN_STANDARD";

    @Column(name = "tax_template", nullable = false, length = 30)
    @Builder.Default
    private String taxTemplate = "GST_INDIA";

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "default_accounts", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, String> defaultAccounts = new HashMap<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "item_fields", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<String> itemFields = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "sample_items", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<Map<String, String>> sampleItems = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "additional_accounts", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<Map<String, String>> additionalAccounts = new ArrayList<>();
}
