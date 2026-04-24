package com.katasticho.erp.organisation;

import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "industry_sub_category")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IndustrySubCategory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "industry_template_id", nullable = false)
    private UUID industryTemplateId;

    @Column(name = "sub_category_code", nullable = false, length = 50)
    private String subCategoryCode;

    @Column(name = "sub_category_label", nullable = false, length = 100)
    private String subCategoryLabel;

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private int sortOrder = 0;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
