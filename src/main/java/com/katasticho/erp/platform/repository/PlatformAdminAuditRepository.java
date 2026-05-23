package com.katasticho.erp.platform.repository;

import com.katasticho.erp.platform.entity.PlatformAdminAudit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface PlatformAdminAuditRepository extends JpaRepository<PlatformAdminAudit, UUID> {
    Page<PlatformAdminAudit> findByPlatformAdminId(UUID adminId, Pageable pageable);
    Page<PlatformAdminAudit> findAll(Pageable pageable);
}
