package com.katasticho.erp.transport.repository;

import com.katasticho.erp.transport.entity.FreightRateCard;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FreightRateCardRepository extends JpaRepository<FreightRateCard, UUID> {

    Optional<FreightRateCard> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<FreightRateCard> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<FreightRateCard> findByOrgIdAndTransporterContactIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, UUID transporterContactId);

    /** Candidate rates for a lane — the service picks the matching weight slab. */
    List<FreightRateCard> findByOrgIdAndTransporterContactIdAndModeAndActiveTrueAndIsDeletedFalse(
            UUID orgId, UUID transporterContactId, String mode);
}
