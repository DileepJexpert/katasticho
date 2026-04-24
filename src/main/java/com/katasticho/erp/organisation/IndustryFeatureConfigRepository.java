package com.katasticho.erp.organisation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface IndustryFeatureConfigRepository extends JpaRepository<IndustryFeatureConfig, UUID> {

    List<IndustryFeatureConfig> findByIndustryTemplateId(UUID industryTemplateId);

    List<IndustryFeatureConfig> findByIndustryTemplateIdAndSubCategoryCodeIn(UUID industryTemplateId, Collection<String> codes);

    Optional<IndustryFeatureConfig> findByIndustryTemplateIdAndSubCategoryCodeIsNull(UUID industryTemplateId);
}
