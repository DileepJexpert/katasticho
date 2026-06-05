package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.PayrollSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface PayrollSettingsRepository extends JpaRepository<PayrollSettings, UUID> {

    Optional<PayrollSettings> findByOrgId(UUID orgId);
}
