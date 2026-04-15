package com.katasticho.erp.organisation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BranchRepository extends JpaRepository<Branch, UUID> {

    Optional<Branch> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<Branch> findByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    Optional<Branch> findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(UUID orgId);

    List<Branch> findByOrgIdAndIsDeletedFalseOrderByName(UUID orgId);

    boolean existsByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);
}
