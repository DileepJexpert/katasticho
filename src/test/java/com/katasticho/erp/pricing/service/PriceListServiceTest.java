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
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for the F3 price resolver and CRUD in
 * {@link PriceListService}. Covers:
 *
 * <ol>
 *   <li>Tiered resolution — multiple rows per (list, item) honour the
 *       highest-{@code minQuantity} rule.</li>
 *   <li>Customer pinned list takes precedence over the org default
 *       list even if both contain the item.</li>
 *   <li>Fall-through — customer without a pinned list hits org
 *       default.</li>
 *   <li>Empty fall-through — no pinned, no default ⇒ empty so caller
 *       keeps the client-supplied price.</li>
 *   <li>Guard — duplicate tier (same minQuantity) rejected.</li>
 *   <li>Default flip — creating a new default unsets the old one in
 *       the same tx.</li>
 * </ol>
 */
@ExtendWith(MockitoExtension.class)
class PriceListServiceTest {

    @Mock private PriceListRepository priceListRepository;
    @Mock private PriceListItemRepository priceListItemRepository;
    @Mock private CustomerRepository customerRepository;

    private PriceListService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new PriceListService(
                priceListRepository, priceListItemRepository, customerRepository);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Resolver tests ───────────────────────────────────────────────────

    /**
     * Three tiers (1+, 10+, 100+) — requesting 50 units should land on
     * the 10+ tier (45), not the 1+ tier (50) and not the 100+ tier (40).
     */
    @Test
    void resolvePrice_tieredLookup_picksHighestMinQuantityThatFits() {
        UUID customerId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID listId = UUID.randomUUID();

        Customer customer = Customer.builder().name("Wholesale Co").build();
        customer.setId(customerId);
        customer.setOrgId(orgId);
        customer.setDefaultPriceListId(listId);

        PriceList list = PriceList.builder().name("Wholesale").currency("INR").active(true).build();
        list.setId(listId);
        list.setOrgId(orgId);

        // Repo returns tiers already sorted minQuantity DESC
        PriceListItem tier100 = tier(listId, itemId, "100", "40");
        PriceListItem tier10 = tier(listId, itemId, "10", "45");
        PriceListItem tier1 = tier(listId, itemId, "1", "50");

        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId))
                .thenReturn(Optional.of(customer));
        when(priceListRepository.findByIdAndOrgIdAndIsDeletedFalse(listId, orgId))
                .thenReturn(Optional.of(list));
        when(priceListItemRepository
                .findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
                        orgId, listId, itemId))
                .thenReturn(List.of(tier100, tier10, tier1));

        Optional<BigDecimal> resolved = service.resolvePrice(customerId, itemId, new BigDecimal("50"));

        assertTrue(resolved.isPresent());
        assertEquals(0, new BigDecimal("45").compareTo(resolved.get()));
    }

    /**
     * Customer has no pinned list → resolver walks to org default and
     * picks the 1+ tier for a small order.
     */
    @Test
    void resolvePrice_noPinnedList_fallsThroughToOrgDefault() {
        UUID customerId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID defaultListId = UUID.randomUUID();

        Customer customer = Customer.builder().name("Walk-in").build();
        customer.setId(customerId);
        customer.setOrgId(orgId);
        // No defaultPriceListId

        PriceList defaultList = PriceList.builder().name("Retail")
                .currency("INR").isDefault(true).active(true).build();
        defaultList.setId(defaultListId);
        defaultList.setOrgId(orgId);

        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId))
                .thenReturn(Optional.of(customer));
        when(priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(defaultList));
        when(priceListItemRepository
                .findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
                        orgId, defaultListId, itemId))
                .thenReturn(List.of(tier(defaultListId, itemId, "1", "99")));

        Optional<BigDecimal> resolved = service.resolvePrice(customerId, itemId, new BigDecimal("3"));

        assertTrue(resolved.isPresent());
        assertEquals(0, new BigDecimal("99").compareTo(resolved.get()));
    }

    /**
     * No pinned, no org default → resolver returns empty so
     * InvoiceService keeps the client-supplied unitPrice unchanged.
     */
    @Test
    void resolvePrice_nothingConfigured_returnsEmpty() {
        UUID customerId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();

        Customer customer = Customer.builder().name("Walk-in").build();
        customer.setId(customerId);
        customer.setOrgId(orgId);

        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId))
                .thenReturn(Optional.of(customer));
        when(priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());

        Optional<BigDecimal> resolved = service.resolvePrice(customerId, itemId, new BigDecimal("10"));

        assertTrue(resolved.isEmpty());
    }

    /**
     * Quantity below every tier's minQuantity → resolver returns empty
     * for this list and falls through (to org default, then empty). The
     * caller still keeps the client unitPrice.
     */
    @Test
    void resolvePrice_quantityBelowAllTiers_fallsThrough() {
        UUID customerId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID listId = UUID.randomUUID();

        Customer customer = Customer.builder().build();
        customer.setId(customerId);
        customer.setOrgId(orgId);
        customer.setDefaultPriceListId(listId);

        PriceList list = PriceList.builder().name("Bulk Only").currency("INR").active(true).build();
        list.setId(listId);
        list.setOrgId(orgId);

        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId))
                .thenReturn(Optional.of(customer));
        when(priceListRepository.findByIdAndOrgIdAndIsDeletedFalse(listId, orgId))
                .thenReturn(Optional.of(list));
        // Only a 100+ tier exists
        when(priceListItemRepository
                .findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
                        orgId, listId, itemId))
                .thenReturn(List.of(tier(listId, itemId, "100", "40")));
        // No org default either
        when(priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());

        Optional<BigDecimal> resolved = service.resolvePrice(customerId, itemId, new BigDecimal("5"));

        assertTrue(resolved.isEmpty());
    }

    // ── CRUD tests ───────────────────────────────────────────────────────

    /**
     * Adding a second tier at the same minQuantity for the same item
     * should be rejected at the service layer (CONFLICT), so the
     * caller gets a clear error before the partial unique index kicks in.
     */
    @Test
    void addItem_duplicateTier_throwsConflict() {
        UUID listId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();

        PriceList list = PriceList.builder().name("Wholesale").currency("INR").active(true).build();
        list.setId(listId);
        list.setOrgId(orgId);

        when(priceListRepository.findByIdAndOrgIdAndIsDeletedFalse(listId, orgId))
                .thenReturn(Optional.of(list));
        when(priceListItemRepository
                .existsByOrgIdAndPriceListIdAndItemIdAndMinQuantityAndIsDeletedFalse(
                        eq(orgId), eq(listId), eq(itemId), any()))
                .thenReturn(true);

        PriceListItemRequest req = new PriceListItemRequest(
                itemId, new BigDecimal("10"), new BigDecimal("45"));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addItem(listId, req));
        assertEquals("PRICING_DUPLICATE_TIER", ex.getErrorCode());
        verify(priceListItemRepository, never()).save(any());
    }

    /**
     * Creating a second default list must flip the first one off in
     * the same transaction — the partial unique index on is_default
     * would otherwise reject the insert.
     */
    @Test
    void createPriceList_newDefault_flipsOldDefaultOff() {
        PriceList existingDefault = PriceList.builder().name("Retail")
                .currency("INR").isDefault(true).active(true).build();
        existingDefault.setId(UUID.randomUUID());
        existingDefault.setOrgId(orgId);

        when(priceListRepository.existsByOrgIdAndNameAndIsDeletedFalse(orgId, "Wholesale"))
                .thenReturn(false);
        when(priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(existingDefault));
        when(priceListRepository.save(any(PriceList.class)))
                .thenAnswer(inv -> {
                    PriceList l = inv.getArgument(0);
                    if (l.getId() == null) l.setId(UUID.randomUUID());
                    return l;
                });

        CreatePriceListRequest req = new CreatePriceListRequest(
                "Wholesale", "For distributors", "INR", true);

        PriceList created = service.createPriceList(req);

        // Both saves happened: one to flip the old default off, one
        // for the new list.
        ArgumentCaptor<PriceList> captor = ArgumentCaptor.forClass(PriceList.class);
        verify(priceListRepository, times(2)).save(captor.capture());

        List<PriceList> saved = captor.getAllValues();
        // First save: existingDefault flipped off
        assertEquals(existingDefault.getId(), saved.get(0).getId());
        assertFalse(saved.get(0).isDefault());
        // Second save: new list with isDefault=true
        assertTrue(saved.get(1).isDefault());
        assertEquals("Wholesale", saved.get(1).getName());

        assertTrue(created.isDefault());
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private PriceListItem tier(UUID listId, UUID itemId, String minQty, String price) {
        PriceListItem row = PriceListItem.builder()
                .priceListId(listId)
                .itemId(itemId)
                .minQuantity(new BigDecimal(minQty))
                .price(new BigDecimal(price))
                .build();
        row.setId(UUID.randomUUID());
        row.setOrgId(orgId);
        return row;
    }
}
