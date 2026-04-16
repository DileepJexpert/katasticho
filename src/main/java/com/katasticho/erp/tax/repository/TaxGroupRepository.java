package com.katasticho.erp.tax.repository;

import com.katasticho.erp.tax.entity.TaxGroup;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TaxGroupRepository extends JpaRepository<TaxGroup, UUID> {

    List<TaxGroup> findByOrgIdAndActiveTrue(UUID orgId);

    Optional<TaxGroup> findByOrgIdAndNameAndActiveTrue(UUID orgId, String name);

    Optional<TaxGroup> findByIdAndOrgId(UUID id, UUID orgId);
}
