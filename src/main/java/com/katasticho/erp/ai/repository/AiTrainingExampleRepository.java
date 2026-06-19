package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.AiTrainingExample;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.UUID;

@Repository
public interface AiTrainingExampleRepository extends JpaRepository<AiTrainingExample, UUID> {

    List<AiTrainingExample> findTop100ByOrgIdAndTaskTypeOrderByCreatedAtDesc(UUID orgId, String taskType);

    // ── Fine-tuning dataset export ──
    Page<AiTrainingExample> findByOrgIdOrderByCreatedAtAsc(UUID orgId, Pageable pageable);

    Page<AiTrainingExample> findByOrgIdAndTaskTypeOrderByCreatedAtAsc(
            UUID orgId, String taskType, Pageable pageable);

    Page<AiTrainingExample> findByOrgIdAndCorrectionTypeInOrderByCreatedAtAsc(
            UUID orgId, java.util.Collection<String> correctionTypes, Pageable pageable);

    long countByOrgId(UUID orgId);
}
