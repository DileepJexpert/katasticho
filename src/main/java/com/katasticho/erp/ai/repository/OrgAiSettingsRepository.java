package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.OrgAiSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.UUID;

@Repository
public interface OrgAiSettingsRepository extends JpaRepository<OrgAiSettings, UUID> {}
