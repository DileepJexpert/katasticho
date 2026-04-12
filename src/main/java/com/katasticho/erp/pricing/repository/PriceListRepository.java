package com.katasticho.erp.pricing.repository;

import com.katasticho.erp.pricing.entity.PriceList;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PriceListRepository extends JpaRepository<PriceList, UUID> {

    Optional<PriceList> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<PriceList> findByOrgIdAndIsDeletedFalseOrderByName(UUID orgId);

    /**
     * The org-wide default price list, if any. Used by the invoice
     * resolver as the second-to-last step in the fall-through chain
     * (before {@code item.sale_price}).
     */
    Optional<PriceList> findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(UUID orgId);

    boolean existsByOrgIdAndNameAndIsDeletedFalse(UUID orgId, String name);
}
