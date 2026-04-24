package com.katasticho.erp.organisation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface IndustryTemplateRepository extends JpaRepository<IndustryTemplate, UUID> {

    List<IndustryTemplate> findByBusinessTypeAndActiveTrueOrderBySortOrder(String businessType);

    Optional<IndustryTemplate> findByIndustryCode(String industryCode);

    List<IndustryTemplate> findAllByActiveTrueOrderByBusinessTypeAscSortOrderAsc();

    @Query("SELECT DISTINCT t.businessType FROM IndustryTemplate t WHERE t.active = true ORDER BY t.businessType")
    List<String> findDistinctBusinessTypes();
}
