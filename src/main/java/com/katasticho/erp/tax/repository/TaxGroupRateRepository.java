package com.katasticho.erp.tax.repository;

import com.katasticho.erp.tax.entity.TaxGroupRate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface TaxGroupRateRepository extends JpaRepository<TaxGroupRate, UUID> {

    List<TaxGroupRate> findByTaxGroupId(UUID taxGroupId);
}
