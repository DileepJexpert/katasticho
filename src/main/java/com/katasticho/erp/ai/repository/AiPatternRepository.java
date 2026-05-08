package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.AiPattern;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AiPatternRepository extends JpaRepository<AiPattern, UUID> {

    List<AiPattern> findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(
            UUID orgId, String patternType, String status);
}
