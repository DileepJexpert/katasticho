package com.katasticho.erp.recurring.repository;

import com.katasticho.erp.recurring.entity.RecurringJournalGeneration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RecurringJournalGenerationRepository extends JpaRepository<RecurringJournalGeneration, UUID> {

    List<RecurringJournalGeneration> findByRecurringJournalIdOrderByGeneratedAtDesc(UUID recurringJournalId);
}
