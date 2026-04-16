package com.katasticho.erp.tax.repository;

import com.katasticho.erp.tax.entity.TaxConfiguration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface TaxConfigurationRepository extends JpaRepository<TaxConfiguration, UUID> {

    Optional<TaxConfiguration> findByOrgIdAndActiveTrue(UUID orgId);

    boolean existsByOrgId(UUID orgId);
}
