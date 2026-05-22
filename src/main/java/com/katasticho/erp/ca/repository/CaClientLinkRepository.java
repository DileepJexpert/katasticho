package com.katasticho.erp.ca.repository;

import com.katasticho.erp.ca.entity.CaClientLink;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CaClientLinkRepository extends JpaRepository<CaClientLink, UUID> {

    Optional<CaClientLink> findByIdAndCaFirmId(UUID id, UUID caFirmId);

    Optional<CaClientLink> findByIdAndCaFirmIdAndStatus(UUID id, UUID caFirmId, String status);

    List<CaClientLink> findByCaFirmIdAndStatusOrderByCreatedAtDesc(UUID caFirmId, String status);

    List<CaClientLink> findByCaFirmIdOrderByCreatedAtDesc(UUID caFirmId);

    List<CaClientLink> findByCaFirmIdAndAssignedUserIdOrCaFirmIdAndBackupUserIdOrderByCreatedAtDesc(
            UUID caFirmId1, UUID assignedUserId, UUID caFirmId2, UUID backupUserId);

    long countByClientOrgIdAndStatus(UUID clientOrgId, String status);

    @Query("""
        SELECT l FROM CaClientLink l
        WHERE l.caFirmId = :caFirmId
          AND l.status = 'ACTIVE'
          AND (:userId IS NULL OR l.assignedUserId = :userId OR l.backupUserId = :userId)
    """)
    List<CaClientLink> findVisibleActive(UUID caFirmId, UUID userId);

    @Query("""
        SELECT COUNT(l) > 0 FROM CaClientLink l
        WHERE l.caFirmId = :caFirmId
          AND l.clientOrgId = :clientOrgId
          AND l.status = 'ACTIVE'
    """)
    boolean existsActiveDelegatedAccess(UUID caFirmId, UUID clientOrgId);
}
