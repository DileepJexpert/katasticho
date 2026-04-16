package com.katasticho.erp.ap.repository;

import com.katasticho.erp.ap.entity.VendorPayment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VendorPaymentRepository extends JpaRepository<VendorPayment, UUID> {

    Optional<VendorPayment> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<VendorPayment> findByOrgIdAndIsDeletedFalseOrderByPaymentDateDesc(UUID orgId, Pageable pageable);

    Page<VendorPayment> findByOrgIdAndContactIdAndIsDeletedFalseOrderByPaymentDateDesc(
            UUID orgId, UUID contactId, Pageable pageable);

    Page<VendorPayment> findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
            UUID orgId, LocalDate from, LocalDate to, Pageable pageable);

    Page<VendorPayment> findByOrgIdAndPaymentModeAndIsDeletedFalseOrderByPaymentDateDesc(
            UUID orgId, String paymentMode, Pageable pageable);

    List<VendorPayment> findByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId);
}
