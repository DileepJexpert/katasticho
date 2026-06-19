package com.katasticho.erp.transport.repository;

import com.katasticho.erp.transport.entity.ProofOfDelivery;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ProofOfDeliveryRepository extends JpaRepository<ProofOfDelivery, UUID> {

    Optional<ProofOfDelivery> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<ProofOfDelivery> findByOrgIdAndIsDeletedFalseOrderByDeliveredAtDesc(UUID orgId);

    List<ProofOfDelivery> findByOrgIdAndDeliveryChallanIdAndIsDeletedFalseOrderByDeliveredAtDesc(
            UUID orgId, UUID deliveryChallanId);
}
