package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.AiTrainingExample;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AiTrainingExampleRepository extends JpaRepository<AiTrainingExample, UUID> {

    List<AiTrainingExample> findTop100ByOrgIdAndTaskTypeOrderByCreatedAtDesc(UUID orgId, String taskType);
}
