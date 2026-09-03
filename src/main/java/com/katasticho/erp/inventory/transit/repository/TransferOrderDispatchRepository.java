package com.katasticho.erp.inventory.transit.repository;

import com.katasticho.erp.inventory.transit.entity.TransferOrderDispatch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TransferOrderDispatchRepository extends JpaRepository<TransferOrderDispatch, UUID> {
    List<TransferOrderDispatch> findByOrgIdAndIsDeletedFalseOrderByDispatchedAtDesc(UUID orgId);
    List<TransferOrderDispatch> findByOrgIdAndStatusAndIsDeletedFalseOrderByDispatchedAtDesc(UUID orgId, String status);
    Optional<TransferOrderDispatch> findByOrgIdAndTransferOrderIdAndIsDeletedFalse(UUID orgId, UUID transferOrderId);
    Optional<TransferOrderDispatch> findByOrgIdAndIdAndIsDeletedFalse(UUID orgId, UUID id);
}
