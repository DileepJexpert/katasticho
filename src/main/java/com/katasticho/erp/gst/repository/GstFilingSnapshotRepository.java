package com.katasticho.erp.gst.repository;

import com.katasticho.erp.gst.entity.GstFilingSnapshot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface GstFilingSnapshotRepository extends JpaRepository<GstFilingSnapshot, UUID> {

    Optional<GstFilingSnapshot> findByOrgIdAndReturnPeriod(UUID orgId, String returnPeriod);
}
