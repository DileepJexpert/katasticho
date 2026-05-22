package com.katasticho.erp.ca.repository;

import com.katasticho.erp.ca.entity.CaReportDispatch;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface CaReportDispatchRepository extends JpaRepository<CaReportDispatch, UUID> {
    long countByDispatchedByAndCreatedAtAfter(UUID dispatchedBy, Instant after);
    List<CaReportDispatch> findTop50ByDispatchedByOrderByCreatedAtDesc(UUID dispatchedBy);
}
