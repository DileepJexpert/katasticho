package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.AiModelRegistry;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface AiModelRegistryRepository extends JpaRepository<AiModelRegistry, UUID> {

    Optional<AiModelRegistry> findFirstByTaskTypeAndStatusOrderByCreatedAtDesc(String taskType, String status);
}
