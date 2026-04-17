package com.katasticho.erp.tax.repository;

import com.katasticho.erp.tax.entity.TaxRate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface TaxRateRepository extends JpaRepository<TaxRate, UUID> {

    List<TaxRate> findByOrgId(UUID orgId);

    List<TaxRate> findByOrgIdAndActiveTrue(UUID orgId);

    List<TaxRate> findByTaxConfigIdAndActiveTrue(UUID taxConfigId);
}
