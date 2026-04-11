package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.EntryNumberSequence;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface EntryNumberSequenceRepository extends JpaRepository<EntryNumberSequence, EntryNumberSequence.EntryNumberSequenceId> {

    @Query("SELECT e FROM EntryNumberSequence e WHERE e.id.orgId = :orgId AND e.id.year = :year")
    Optional<EntryNumberSequence> findByOrgIdAndYear(java.util.UUID orgId, int year);

    @Modifying
    @Query("UPDATE EntryNumberSequence e SET e.nextValue = e.nextValue + 1 WHERE e.id.orgId = :orgId AND e.id.year = :year")
    int incrementAndGet(java.util.UUID orgId, int year);
}
