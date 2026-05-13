package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.AiUsageLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface AiUsageLogRepository extends JpaRepository<AiUsageLog, UUID> {
}
