package com.katasticho.erp.partnernetwork.repository;

import com.katasticho.erp.partnernetwork.entity.TradingPartner;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TradingPartnerRepository extends JpaRepository<TradingPartner, UUID> {

    List<TradingPartner> findAllBySellerOrgIdAndIsDeletedFalse(UUID sellerOrgId);

    List<TradingPartner> findAllByBuyerOrgIdAndIsDeletedFalse(UUID buyerOrgId);

    List<TradingPartner> findAllBySellerOrgIdAndStatusAndIsDeletedFalse(UUID sellerOrgId, String status);

    List<TradingPartner> findAllByBuyerOrgIdAndStatusAndIsDeletedFalse(UUID buyerOrgId, String status);

    Optional<TradingPartner> findBySellerOrgIdAndBuyerOrgIdAndIsDeletedFalse(UUID sellerOrgId, UUID buyerOrgId);

    @Query("SELECT tp FROM TradingPartner tp WHERE (tp.sellerOrgId = :orgId OR tp.buyerOrgId = :orgId) AND tp.status = :status AND tp.isDeleted = false")
    List<TradingPartner> findAllByOrgIdAndStatus(UUID orgId, String status);

    @Query("SELECT tp FROM TradingPartner tp WHERE (tp.sellerOrgId = :orgId OR tp.buyerOrgId = :orgId) AND tp.isDeleted = false")
    List<TradingPartner> findAllByOrgId(UUID orgId);

    Optional<TradingPartner> findByIdAndIsDeletedFalse(UUID id);
}
