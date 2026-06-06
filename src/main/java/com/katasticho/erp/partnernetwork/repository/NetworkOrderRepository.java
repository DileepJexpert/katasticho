package com.katasticho.erp.partnernetwork.repository;

import com.katasticho.erp.partnernetwork.entity.NetworkOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface NetworkOrderRepository extends JpaRepository<NetworkOrder, UUID> {

    List<NetworkOrder> findAllByBuyerOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID buyerOrgId);

    List<NetworkOrder> findAllBySellerOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID sellerOrgId);

    List<NetworkOrder> findAllBySellerOrgIdAndStatusAndIsDeletedFalse(UUID sellerOrgId, String status);

    Optional<NetworkOrder> findByIdAndIsDeletedFalse(UUID id);

    Optional<NetworkOrder> findByBuyerPoIdAndIsDeletedFalse(UUID buyerPoId);

    Optional<NetworkOrder> findBySellerSoIdAndIsDeletedFalse(UUID sellerSoId);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(o.orderNumber, 4) AS int)), 0) FROM NetworkOrder o WHERE o.buyerOrgId = :orgId")
    int findMaxOrderNumber(UUID orgId);
}
