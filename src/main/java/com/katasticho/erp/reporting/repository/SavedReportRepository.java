package com.katasticho.erp.reporting.repository;

import com.katasticho.erp.reporting.entity.SavedReport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface SavedReportRepository extends JpaRepository<SavedReport, UUID> {

    /**
     * Returns all non-deleted saved reports for an org that the user either owns
     * or that have been marked public.
     */
    @Query("SELECT r FROM SavedReport r " +
           "WHERE r.orgId = :orgId AND r.deleted = false " +
           "AND (r.createdBy = :userId OR r.isPublic = true) " +
           "ORDER BY r.createdAt DESC")
    List<SavedReport> findByOrgIdAndUser(@Param("orgId") UUID orgId,
                                         @Param("userId") UUID userId);
}
