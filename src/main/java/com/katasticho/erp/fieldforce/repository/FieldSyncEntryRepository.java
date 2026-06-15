package com.katasticho.erp.fieldforce.repository;

import com.katasticho.erp.fieldforce.entity.FieldSyncEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface FieldSyncEntryRepository extends JpaRepository<FieldSyncEntry, UUID> {

    Optional<FieldSyncEntry> findByOrgIdAndSalespersonIdAndClientId(
            UUID orgId, UUID salespersonId, String clientId);
}
