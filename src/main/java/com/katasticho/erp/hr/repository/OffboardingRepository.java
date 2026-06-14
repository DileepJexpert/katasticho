package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.Offboarding;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OffboardingRepository extends JpaRepository<Offboarding, UUID> {

    Optional<Offboarding> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<Offboarding> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<Offboarding> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String status);
}
