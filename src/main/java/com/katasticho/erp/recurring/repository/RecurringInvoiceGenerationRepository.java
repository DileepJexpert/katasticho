package com.katasticho.erp.recurring.repository;

import com.katasticho.erp.recurring.entity.RecurringInvoiceGeneration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RecurringInvoiceGenerationRepository
        extends JpaRepository<RecurringInvoiceGeneration, UUID> {

    List<RecurringInvoiceGeneration> findByRecurringInvoiceIdOrderByGeneratedAtDesc(
            UUID recurringInvoiceId);
}
