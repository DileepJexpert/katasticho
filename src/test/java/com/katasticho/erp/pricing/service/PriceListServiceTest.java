package com.katasticho.erp.pricing.service;

import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.repository.ItemRepository;
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

@ExtendWith(MockitoExtension.class)
class PriceListServiceTest {

    @Mock private PriceListRepository priceListRepository;
    @Mock private PriceListItemRepository priceListItemRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private ItemRepository itemRepository;

    private PriceListService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new PriceListService(
                priceListRepository, priceListItemRepository, contactRepository, itemRepository);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void resolvePrice_tieredLookup_picksHighestMinQuantityThatFits() {
        UUID contactId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID listId = UUID.randomUUID();

        Contact contact = Contact.builder().displayName("Wholesale Co").contactType(ContactType.CUSTOMER).build();
        contact.setId(contactId);
        contact.setOrgId(orgId);
        contact.setDefaultPriceListId(listId);

        PriceList list = PriceList.builder().name("Wholesale").currency("INR").active(true).build();
        list.setId(listId);
        list.setOrgId(orgId);

        PriceListItem tier100 = tier(listId, itemId, "100", "40");
        PriceListItem tier10 = tier(listId, itemId, "10", "45");
        PriceListItem tier1 = tier(listId, itemId, "1", "50");

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(priceListRepository.findByIdAndOrgIdAndIsDeletedFalse(listId, orgId))
                .thenReturn(Optional.of(list));
        when(priceListItemRepository
                .findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
                        orgId, listId, itemId))
                .thenReturn(List.of(tier100, tier10, tier1));

        Optional<BigDecimal> resolved = service.resolvePrice(contactId, itemId, new BigDecimal("50"));

        assertTrue(resolved.isPresent());
        assertEquals(0, new BigDecimal("45").compareTo(resolved.get()));
    }

    @Test
    void resolvePrice_noPinnedList_fallsThroughToOrgDefault() {
        UUID contactId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID defaultListId = UUID.randomUUID();

        Contact contact = Contact.builder().displayName("Walk-in").contactType(ContactType.CUSTOMER).build();
        contact.setId(contactId);
        contact.setOrgId(orgId);

        PriceList defaultList = PriceList.builder().name("Retail")
                .currency("INR").isDefault(true).active(true).build();
        defaultList.setId(defaultListId);
        defaultList.setOrgId(orgId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(defaultList));
        when(priceListItemRepository
                .findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
                        orgId, defaultListId, itemId))
                .thenReturn(List.of(tier(defaultListId, itemId, "1", "99")));

        Optional<BigDecimal> resolved = service.resolvePrice(contactId, itemId, new BigDecimal("3"));

        assertTrue(resolved.isPresent());
        assertEquals(0, new BigDecimal("99").compareTo(resolved.get()));
    }

    @Test
    void resolvePrice_nothingConfigured_returnsEmpty() {
        UUID contactId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();

        Contact contact = Contact.builder().displayName("Walk-in").contactType(ContactType.CUSTOMER).build();
        contact.setId(contactId);
        contact.setOrgId(orgId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());

        Optional<BigDecimal> resolved = service.resolvePrice(contactId, itemId, new BigDecimal("10"));

        assertTrue(resolved.isEmpty());
    }

    @Test
    void resolvePrice_quantityBelowAllTiers_fallsThrough() {
        UUID contactId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID listId = UUID.randomUUID();

        Contact contact = Contact.builder().displayName("Buyer").contactType(ContactType.CUSTOMER).build();
        contact.setId(contactId);
        contact.setOrgId(orgId);
        contact.setDefaultPriceListId(listId);

        PriceList list = PriceList.builder().name("Bulk Only").currency("INR").active(true).build();
        list.setId(listId);
        list.setOrgId(orgId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(priceListRepository.findByIdAndOrgIdAndIsDeletedFalse(listId, orgId))
                .thenReturn(Optional.of(list));
        when(priceListItemRepository
                .findByOrgIdAndPriceListIdAndItemIdAndIsDeletedFalseOrderByMinQuantityDesc(
                        orgId, listId, itemId))
                .thenReturn(List.of(tier(listId, itemId, "100", "40")));
        when(priceListRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());

        Optional<BigDecimal> resolved = service.resolvePrice(contactId, itemId, new BigDecimal("5"));

        assertTrue(resolved.isEmpty());
    }

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

        ArgumentCaptor<PriceList> captor = ArgumentCaptor.forClass(PriceList.class);
        verify(priceListRepository, times(2)).save(captor.capture());

        List<PriceList> saved = captor.getAllValues();
        assertEquals(existingDefault.getId(), saved.get(0).getId());
        assertFalse(saved.get(0).isDefault());
        assertTrue(saved.get(1).isDefault());
        assertEquals("Wholesale", saved.get(1).getName());

        assertTrue(created.isDefault());
    }

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
