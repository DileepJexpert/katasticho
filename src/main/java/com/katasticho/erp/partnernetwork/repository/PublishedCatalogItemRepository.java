package com.katasticho.erp.partnernetwork.repository;

import com.katasticho.erp.partnernetwork.entity.PublishedCatalogItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PublishedCatalogItemRepository extends JpaRepository<PublishedCatalogItem, UUID> {

    List<PublishedCatalogItem> findAllByOrgIdAndIsActiveAndIsDeletedFalse(UUID orgId, boolean isActive);

    Optional<PublishedCatalogItem> findByOrgIdAndItemIdAndIsDeletedFalse(UUID orgId, UUID itemId);

    Optional<PublishedCatalogItem> findByIdAndIsDeletedFalse(UUID id);

    @Query("SELECT c FROM PublishedCatalogItem c WHERE c.orgId IN :sellerOrgIds AND c.isActive = true AND c.isDeleted = false " +
           "AND (LOWER(c.displayName) LIKE LOWER(CONCAT('%', :search, '%')) OR LOWER(c.publishedSku) LIKE LOWER(CONCAT('%', :search, '%')) " +
           "OR LOWER(c.manufacturer) LIKE LOWER(CONCAT('%', :search, '%')))")
    List<PublishedCatalogItem> searchAcrossSuppliers(List<UUID> sellerOrgIds, String search);

    @Query("SELECT c FROM PublishedCatalogItem c WHERE c.orgId IN :sellerOrgIds AND c.isActive = true AND c.isDeleted = false")
    List<PublishedCatalogItem> findAllBySuppliers(List<UUID> sellerOrgIds);

    List<PublishedCatalogItem> findAllByOrgIdAndIsDeletedFalse(UUID orgId);

    @Query("SELECT c FROM PublishedCatalogItem c WHERE c.drugMasterId = :drugMasterId AND c.orgId IN :sellerOrgIds " +
           "AND c.isActive = true AND c.isDeleted = false")
    List<PublishedCatalogItem> findByDrugMasterIdAcrossSuppliers(UUID drugMasterId, List<UUID> sellerOrgIds);
}
