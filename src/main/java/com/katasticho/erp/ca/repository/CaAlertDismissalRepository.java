package com.katasticho.erp.ca.repository;

import com.katasticho.erp.ca.entity.CaAlertDismissal;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

public interface CaAlertDismissalRepository extends JpaRepository<CaAlertDismissal, UUID> {
    Set<CaAlertDismissal> findByCaFirmIdAndSuggestionIdIn(UUID caFirmId, Collection<UUID> suggestionIds);
    Optional<CaAlertDismissal> findByCaFirmIdAndSuggestionId(UUID caFirmId, UUID suggestionId);
}
