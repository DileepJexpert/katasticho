package com.katasticho.erp.pricing.repository;

import com.katasticho.erp.pricing.entity.PriceListItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PriceListItemRepository extends JpaRepository<PriceListItem, UUID> {

    Optional<PriceListItem> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /**
     * All tiers for one (list, item) pair, ordered by {@code minQuantity DESC}
     * so the resolver can pick the first row whose {@code minQuantity} is
     * &le; the requested quantity and stop. Includes org scoping so a
     * mis-wired list id can't leak rows across tenants.
     */
    List<PriceListItem>
        findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
            UUID orgId, UUID priceListId, UUID itemId);

    List<PriceListItem> findByOrgIdAndPriceListIdAndIsDeletedFalseOrderByItemIdAsc(
            UUID orgId, UUID priceListId);

    boolean existsByOrgIdAndPriceListIdAndItemIdAndMinQuantityAndIsDeletedFalse(
            UUID orgId, UUID priceListId, UUID itemId, BigDecimal minQuantity);
}
