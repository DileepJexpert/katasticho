package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldAllowanceClaim;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FieldAllowanceClaimRepository extends JpaRepository<FieldAllowanceClaim, UUID> {

    Optional<FieldAllowanceClaim> findByOrgIdAndSalespersonIdAndClaimDate(
            UUID orgId, UUID salespersonId, LocalDate claimDate);

    List<FieldAllowanceClaim> findByOrgIdAndSalespersonIdOrderByClaimDateDesc(
            UUID orgId, UUID salespersonId);
}
