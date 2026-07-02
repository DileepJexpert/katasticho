package com.katasticho.erp.recurring.repository;

import com.katasticho.erp.recurring.entity.RecurringBillGeneration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RecurringBillGenerationRepository extends JpaRepository<RecurringBillGeneration, UUID> {

    List<RecurringBillGeneration> findByRecurringBillIdOrderByGeneratedAtDesc(UUID recurringBillId);
}
