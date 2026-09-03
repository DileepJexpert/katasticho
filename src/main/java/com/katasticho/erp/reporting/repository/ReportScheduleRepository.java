package com.katasticho.erp.reporting.repository;

import com.katasticho.erp.reporting.entity.ReportSchedule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ReportScheduleRepository extends JpaRepository<ReportSchedule, UUID> {

    List<ReportSchedule> findBySavedReportIdAndOrgId(UUID savedReportId, UUID orgId);

    List<ReportSchedule> findByOrgIdAndActive(UUID orgId, boolean active);
}
