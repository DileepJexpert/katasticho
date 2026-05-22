package com.katasticho.erp.ca.repository;

import com.katasticho.erp.ca.entity.CaFirm;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface CaFirmRepository extends JpaRepository<CaFirm, UUID> {
    Optional<CaFirm> findByOrgIdAndActiveTrue(UUID orgId);
}
