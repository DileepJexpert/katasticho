package com.katasticho.erp.paymentterm.repository;

import com.katasticho.erp.paymentterm.entity.PaymentTerm;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PaymentTermRepository extends JpaRepository<PaymentTerm, UUID> {

    Optional<PaymentTerm> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<PaymentTerm> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    List<PaymentTerm> findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByNameAsc(UUID orgId);
}
