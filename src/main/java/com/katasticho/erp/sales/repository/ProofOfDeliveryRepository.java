package com.katasticho.erp.sales.repository;

import com.katasticho.erp.sales.entity.ProofOfDelivery;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ProofOfDeliveryRepository extends JpaRepository<ProofOfDelivery, UUID> {

    Optional<ProofOfDelivery> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<ProofOfDelivery> findByOrgIdAndDeliveryChallanIdAndIsDeletedFalseOrderByDeliveredAtDesc(
            UUID orgId, UUID deliveryChallanId);

    List<ProofOfDelivery> findByOrgIdAndInvoiceIdAndIsDeletedFalseOrderByDeliveredAtDesc(
            UUID orgId, UUID invoiceId);

    List<ProofOfDelivery> findByOrgIdAndContactIdAndIsDeletedFalseOrderByDeliveredAtDesc(
            UUID orgId, UUID contactId);

    List<ProofOfDelivery> findTop50ByOrgIdAndIsDeletedFalseOrderByDeliveredAtDesc(UUID orgId);
}
