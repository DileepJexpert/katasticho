package com.katasticho.erp.accounting.forex.repository;

import com.katasticho.erp.accounting.forex.entity.ForexRevaluationRun;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ForexRevaluationRunRepository extends JpaRepository<ForexRevaluationRun, UUID> {

    Optional<ForexRevaluationRun> findByOrgIdAndAsOfDate(UUID orgId, LocalDate asOfDate);

    List<ForexRevaluationRun> findByOrgIdOrderByAsOfDateDesc(UUID orgId);
}
