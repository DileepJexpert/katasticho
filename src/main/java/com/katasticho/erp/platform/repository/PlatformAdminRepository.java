package com.katasticho.erp.platform.repository;

import com.katasticho.erp.platform.entity.PlatformAdmin;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface PlatformAdminRepository extends JpaRepository<PlatformAdmin, UUID> {
    Optional<PlatformAdmin> findByEmailAndActiveTrue(String email);
    Optional<PlatformAdmin> findByEmail(String email);
}
