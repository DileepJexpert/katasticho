package com.katasticho.erp.organisation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface IndustrySubCategoryRepository extends JpaRepository<IndustrySubCategory, UUID> {

    List<IndustrySubCategory> findByIndustryTemplateIdAndActiveTrueOrderBySortOrder(UUID industryTemplateId);
}
