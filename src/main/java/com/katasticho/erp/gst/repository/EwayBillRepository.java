package com.katasticho.erp.gst.repository;

import com.katasticho.erp.gst.entity.EwayBill;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EwayBillRepository extends JpaRepository<EwayBill, UUID> {

    Optional<EwayBill> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    boolean existsByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalse(
            UUID orgId, String documentType, UUID documentId);

    List<EwayBill> findByOrgIdAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(UUID orgId);

    List<EwayBill> findByOrgIdAndStatusAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(
            UUID orgId, String status);

    long countByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);

    /** Same-vehicle, same-day rows — the e-way vehicle aggregate rule. */
    List<EwayBill> findByOrgIdAndVehicleNumberIgnoreCaseAndDocumentDateAndIsDeletedFalse(
            UUID orgId, String vehicleNumber, LocalDate documentDate);
}
