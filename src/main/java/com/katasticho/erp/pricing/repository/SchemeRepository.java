package com.katasticho.erp.pricing.repository;

import com.katasticho.erp.pricing.entity.Scheme;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SchemeRepository extends JpaRepository<Scheme, UUID> {
    List<Scheme> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);
    Optional<Scheme> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    @Query("""
        SELECT s FROM Scheme s
        WHERE s.orgId = :orgId
          AND s.isDeleted = false
          AND s.active = true
          AND (s.itemId = :itemId OR s.itemId IS NULL)
          AND (s.validFrom IS NULL OR s.validFrom <= :today)
          AND (s.validTo IS NULL OR s.validTo >= :today)
    """)
    List<Scheme> findApplicable(UUID orgId, UUID itemId, LocalDate today);
}
