package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.AiModelRun;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface AiModelRunRepository extends JpaRepository<AiModelRun, UUID> {
}
