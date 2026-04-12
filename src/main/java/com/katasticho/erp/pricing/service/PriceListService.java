package com.katasticho.erp.pricing.service;

import com.katasticho.erp.ar.entity.Customer;
import com.katasticho.erp.ar.repository.CustomerRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.pricing.dto.CreatePriceListRequest;
import com.katasticho.erp.pricing.dto.PriceListItemRequest;
import com.katasticho.erp.pricing.entity.PriceList;
import com.katasticho.erp.pricing.entity.PriceListItem;
import com.katasticho.erp.pricing.repository.PriceListItemRepository;
import com.katasticho.erp.pricing.repository.PriceListRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Price list lifecycle + the {@link #resolvePrice} hot path used by
 * {@code InvoiceService.createInvoice}.
 *
 * <p>The resolver implements the v2 F3 fall-through chain:
 * <ol>
 *   <li>If the customer has a pinned {@code defaultPriceListId}, look
 *       up the highest tier in that list whose {@code minQuantity} is
 *       &le; the requested quantity.</li>
 *   <li>Else if the org has a default price list (is_default = true),
 *       do the same tier lookup there.</li>
 *   <li>Else return {@link Optional#empty()} — caller falls back to
 *       the client-supplied unit price, which itself falls back to
 *       {@code item.sale_price} via the Flutter item picker.</li>
 * </ol>
 *
 * <p>Only active, non-deleted lists participate. A soft-deleted list
 * still attached to a customer is skipped silently and the resolver
 * falls through to the next step — there's no loud failure because the
 * customer may have been set up long before the list was retired.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PriceListService {

    private final PriceListRepository priceListRepository;
    private final PriceListItemRepository priceListItemRepository;
    private final CustomerRepository customerRepository;

    // ────────────────────────────────────────────────────────────────────
    // Price list CRUD
    // ────────────────────────────────────────────────────────────────────

    @Transactional
    public PriceList createPriceList(CreatePriceListRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String name = request.name().trim();

        if (priceListRepository.existsByOrgIdAndNameAndIsDeletedFalse(orgId, name)) {
            throw new BusinessException(
                    "Price list with name '" + name + "' already exists",
                    "PRICING_DUPLICATE_NAME", HttpStatus.CONFLICT);
        }

        String currency = request.currency() != null
                ? request.currency().toUpperCase()
                : "INR";

        // If the caller asks for a new default, flip the existing
        // default off first in the same transaction. The partial unique
        // index would otherwise reject the insert.
        if (request.isDefault()) {
            unsetCurrentDefault(orgId);
        }

        PriceList list = PriceList.builder()
                .name(name)
                .description(request.description())
                .currency(currency)
                .isDefault(request.isDefault())
                .active(true)
                .build();

        PriceList saved = priceListRepository.save(list);
        log.info("Price list {} created: currency={}, default={}",
                saved.getName(), saved.getCurrency(), saved.isDefault());
        return saved;
    }

    @Transactional(readOnly = true)
    public PriceList getPriceList(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return priceListRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PriceList", id));
    }

    @Transactional(readOnly = true)
    public List<PriceList> listPriceLists() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return priceListRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId);
    }

    @Transactional
    public void deletePriceList(UUID id) {
        PriceList list = getPriceList(id);
        list.setDeleted(true);
        list.setActive(false);
        priceListRepository.save(list);
        log.info("Price list {} soft-deleted", list.getName());
    }

    /**
     * Flip the current org default OFF so a new list can claim
     * {@code is_default = true}. Idempotent — no-op if no default
     * exists. Called from inside {@link #createPriceList} when the
     * caller wants to install a new default.
     */
    private void unsetCurrentDefault(UUID orgId) {
        priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .ifPresent(existing -> {
                    existing.setDefault(false);
                    priceListRepository.save(existing);
                    log.info("Price list {} unset as default (replaced)", existing.getName());
                });
    }

    // ────────────────────────────────────────────────────────────────────
    // Price list item CRUD
    // ────────────────────────────────────────────────────────────────────

    @Transactional
    public PriceListItem addItem(UUID priceListId, PriceListItemRequest request) {
        PriceList list = getPriceList(priceListId); // tenant-checks
        UUID orgId = list.getOrgId();

        BigDecimal minQty = request.minQuantity();
        if (minQty.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException(
                    "minQuantity must be positive",
                    "PRICING_MIN_QTY_INVALID", HttpStatus.BAD_REQUEST);
        }

        boolean dup = priceListItemRepository
                .existsByOrgIdAndPriceListIdAndItemIdAndMinQuantityAndIsDeletedFalse(
                        orgId, priceListId, request.itemId(), minQty);
        if (dup) {
            throw new BusinessException(
                    "A tier at minQuantity " + minQty + " already exists for this item",
                    "PRICING_DUPLICATE_TIER", HttpStatus.CONFLICT);
        }

        PriceListItem row = PriceListItem.builder()
                .priceListId(priceListId)
                .itemId(request.itemId())
                .minQuantity(minQty)
                .price(request.price())
                .build();
        return priceListItemRepository.save(row);
    }

    @Transactional(readOnly = true)
    public List<PriceListItem> listItems(UUID priceListId) {
        PriceList list = getPriceList(priceListId); // tenant-checks
        return priceListItemRepository
                .findByOrgIdAndPriceListIdAndIsDeletedFalseOrderByItemIdAsc(
                        list.getOrgId(), priceListId);
    }

    @Transactional
    public void deleteItem(UUID priceListItemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PriceListItem row = priceListItemRepository
                .findByIdAndOrgIdAndIsDeletedFalse(priceListItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PriceListItem", priceListItemId));
        row.setDeleted(true);
        priceListItemRepository.save(row);
    }

    // ────────────────────────────────────────────────────────────────────
    // Resolver — the invoice-create hot path
    // ────────────────────────────────────────────────────────────────────

    /**
     * Look up a price for {@code (customerId, itemId, quantity)} by
     * walking the fall-through chain. Returns {@link Optional#empty()}
     * if neither the customer's pinned list nor the org default has a
     * matching row — the invoice service then keeps the client-supplied
     * unit price unchanged.
     *
     * <p>Input quantity is required so tier resolution works. The
     * resolver is read-only and joins the caller's transaction.
     */
    @Transactional(readOnly = true)
    public Optional<BigDecimal> resolvePrice(UUID customerId, UUID itemId, BigDecimal quantity) {
        if (itemId == null || quantity == null) {
            return Optional.empty();
        }
        UUID orgId = TenantContext.getCurrentOrgId();

        // 1. Customer-pinned list
        Optional<PriceList> pinned = Optional.empty();
        if (customerId != null) {
            pinned = customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId)
                    .map(Customer::getDefaultPriceListId)
                    .flatMap(id -> priceListRepository
                            .findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                    .filter(PriceList::isActive);
        }
        Optional<BigDecimal> fromPinned = pinned
                .flatMap(list -> lookupTier(orgId, list.getId(), itemId, quantity));
        if (fromPinned.isPresent()) {
            return fromPinned;
        }

        // 2. Org default list (only consult if we haven't already tried
        // it as the customer's pinned list — avoids double-lookup).
        Optional<PriceList> orgDefault = priceListRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .filter(PriceList::isActive);
        if (orgDefault.isPresent()
                && pinned.map(p -> !p.getId().equals(orgDefault.get().getId())).orElse(true)) {
            return lookupTier(orgId, orgDefault.get().getId(), itemId, quantity);
        }

        return Optional.empty();
    }

    /**
     * Walk the tiers of one list for one item (already ordered
     * {@code minQuantity DESC}) and return the first row whose
     * {@code minQuantity} is &le; the requested quantity. Returns empty
     * if the list has no rows for this item, or if every tier requires
     * more than the requested quantity.
     */
    private Optional<BigDecimal> lookupTier(UUID orgId, UUID priceListId, UUID itemId, BigDecimal quantity) {
        List<PriceListItem> tiers = priceListItemRepository
                .findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
                        orgId, priceListId, itemId);
        for (PriceListItem tier : tiers) {
            if (tier.getMinQuantity().compareTo(quantity) <= 0) {
                return Optional.of(tier.getPrice());
            }
        }
        return Optional.empty();
    }
}
