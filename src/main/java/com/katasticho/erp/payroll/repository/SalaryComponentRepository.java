package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.SalaryComponent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SalaryComponentRepository extends JpaRepository<SalaryComponent, UUID> {

    List<SalaryComponent> findByOrgIdAndIsActiveTrueOrderByCodeAsc(UUID orgId);

    Optional<SalaryComponent> findByOrgIdAndCode(UUID orgId, String code);
}
