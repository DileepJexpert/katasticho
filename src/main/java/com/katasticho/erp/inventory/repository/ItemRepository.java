package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.Item;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ItemRepository extends JpaRepository<Item, UUID> {

    Optional<Item> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<Item> findByOrgIdAndSkuAndIsDeletedFalse(UUID orgId, String sku);

    boolean existsByOrgIdAndSkuAndIsDeletedFalse(UUID orgId, String sku);

    Page<Item> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    Page<Item> findByOrgIdAndIsDeletedFalseAndActiveTrue(UUID orgId, Pageable pageable);

    @Query("""
            SELECT i FROM Item i
            WHERE i.orgId = :orgId
              AND i.isDeleted = false
              AND (LOWER(i.name) LIKE LOWER(CONCAT('%', :q, '%'))
                OR LOWER(i.sku)  LIKE LOWER(CONCAT('%', :q, '%')))
            """)
    Page<Item> search(@Param("orgId") UUID orgId, @Param("q") String q, Pageable pageable);

    List<Item> findByOrgIdAndIsDeletedFalseAndTrackInventoryTrue(UUID orgId);
}
