package com.katasticho.erp.portal.service;

import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.portal.entity.PortalUser;
import com.katasticho.erp.portal.repository.PortalUserRepository;
import com.katasticho.erp.pricing.dto.SchemeResponse;
import com.katasticho.erp.pricing.service.PriceListService;
import com.katasticho.erp.pricing.service.SchemeService;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.sales.dto.CreateSalesOrderRequest;
import com.katasticho.erp.sales.dto.SalesOrderResponse;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.sales.service.SalesOrderService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PortalReorderServiceTest {

    @Mock private PortalUserRepository portalUserRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PurchaseBillRepository purchaseBillRepository;
    @Mock private PurchaseOrderRepository purchaseOrderRepository;
    @Mock private ContactLedgerService contactLedgerService;
    @Mock private ItemRepository itemRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private PriceListService priceListService;
    @Mock private SchemeService schemeService;
    @Mock private SalesOrderRepository salesOrderRepository;
    @Mock private SalesOrderService salesOrderService;

    private PortalDataService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID portalUserId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new PortalDataService(
                portalUserRepository,
                contactRepository,
                invoiceRepository,
                purchaseBillRepository,
                purchaseOrderRepository,
                contactLedgerService,
                itemRepository,
                stockBalanceRepository,
                priceListService,
                schemeService,
                salesOrderRepository,
                salesOrderService
        );

        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(portalUserId);

        PortalUser pu = PortalUser.builder()
                .orgId(orgId)
                .contactId(contactId)
                .kind("CUSTOMER")
                .status("ACTIVE")
                .email("chemist@retail.test")
                .fullName("City Medicos")
                .build();
        pu.setId(portalUserId);

        when(portalUserRepository.findByIdAndIsDeletedFalse(portalUserId)).thenReturn(Optional.of(pu));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void catalog_returnsSearchableItemsWithPricingAndSchemes() {
        UUID itemId = UUID.randomUUID();
        Item item = Item.builder()
                .sku("DOLO650")
                .name("Dolo 650mg Tablet")
                .brand("Micro Labs")
                .composition("Paracetamol 650mg")
                .packSize("15 Tablets/Strip")
                .unitOfMeasure("STRIP")
                .salePrice(new BigDecimal("30.00"))
                .mrp(new BigDecimal("35.00"))
                .gstRate(new BigDecimal("5.00"))
                .trackInventory(true)
                .build();
        item.setId(itemId);

        when(itemRepository.search(eq(orgId), eq("Dolo"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(item)));
        when(stockBalanceRepository.findByOrgIdAndItemIdIn(eq(orgId), anyList()))
                .thenReturn(List.of(StockBalance.builder().itemId(itemId).quantityOnHand(new BigDecimal("120")).build()));
        when(priceListService.resolvePrice(eq(contactId), eq(itemId), any(BigDecimal.class)))
                .thenReturn(Optional.of(new BigDecimal("28.50")));

        SchemeResponse scheme = new SchemeResponse(
                UUID.randomUUID(), "10+1 Free", "BUY_X_GET_Y", itemId, "Dolo 650mg",
                new BigDecimal("10"), new BigDecimal("1"), BigDecimal.ZERO, BigDecimal.ZERO,
                LocalDate.now().minusDays(1), LocalDate.now().plusDays(30), null, null, true, null
        );
        when(schemeService.getApplicable(eq(itemId), any(BigDecimal.class)))
                .thenReturn(List.of(scheme));

        Map<String, Object> result = service.catalog("Dolo", null, 0, 10);
        assertNotNull(result);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) result.get("items");
        assertEquals(1, items.size());

        Map<String, Object> first = items.get(0);
        assertEquals("Dolo 650mg Tablet", first.get("name"));
        assertEquals(new BigDecimal("28.50"), first.get("salePrice"));
        assertEquals(new BigDecimal("120"), first.get("stockQuantity"));
        assertTrue((Boolean) first.get("inStock"));
        assertEquals("Buy 10 Get 1 Free", first.get("schemeDescription"));
    }

    @Test
    void placeOrder_createsSalesOrderSuccessfully() {
        UUID itemId = UUID.randomUUID();
        Item item = Item.builder()
                .sku("AZI500")
                .name("Azithral 500mg")
                .salePrice(new BigDecimal("120.00"))
                .unitOfMeasure("STRIP")
                .gstRate(new BigDecimal("5.00"))
                .build();
        item.setId(itemId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)).thenReturn(Optional.of(item));

        SalesOrderResponse soResponse = new SalesOrderResponse(
                UUID.randomUUID(), "SO-2026-0099", contactId, "City Medicos",
                LocalDate.now(), LocalDate.now().plusDays(1), "PORTAL-ORD", "CONFIRMED", "NOT_SHIPPED", "NOT_INVOICED",
                null, null, "INR", "ITEM_LEVEL", BigDecimal.ZERO, new BigDecimal("240.00"), new BigDecimal("12.00"),
                BigDecimal.ZERO, BigDecimal.ZERO, null, new BigDecimal("252.00"),
                "STANDARD", null, "Please pack in morning batch", null, null, null,
                List.of(), 0, 0, true, null, List.of(), null, null
        );
        when(salesOrderService.create(any(CreateSalesOrderRequest.class))).thenReturn(soResponse);

        Map<String, Object> orderReq = new LinkedHashMap<>();
        orderReq.put("notes", "Please pack in morning batch");
        orderReq.put("lines", List.of(Map.of("itemId", itemId.toString(), "quantity", "2")));

        Map<String, Object> result = service.placeOrder(orderReq);
        assertNotNull(result);
        assertEquals("SO-2026-0099", result.get("salesorderNumber"));
        assertEquals(new BigDecimal("252.00"), result.get("total"));
        assertEquals("CONFIRMED", result.get("status"));
        assertEquals(1, result.get("itemCount"));
    }

    @Test
    void orders_listsCustomerSalesOrdersWithFulfillmentStatus() {
        SalesOrder so = SalesOrder.builder()
                .salesorderNumber("SO-2026-0050")
                .referenceNumber("PORTAL-ORD")
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .status("CONFIRMED")
                .shippedStatus("NOT_SHIPPED")
                .invoicedStatus("NOT_INVOICED")
                .subtotal(new BigDecimal("500.00"))
                .taxAmount(new BigDecimal("25.00"))
                .total(new BigDecimal("525.00"))
                .lines(List.of(SalesOrderLine.builder().lineNumber(1).quantity(new BigDecimal("5")).amount(new BigDecimal("500")).build()))
                .build();
        so.setId(UUID.randomUUID());

        when(salesOrderRepository.findByOrgIdAndContactIdAndIsDeletedFalse(eq(orgId), eq(contactId), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(so)));

        List<Map<String, Object>> list = service.orders();
        assertEquals(1, list.size());
        assertEquals("SO-2026-0050", list.get(0).get("number"));
        assertEquals(new BigDecimal("525.00"), list.get(0).get("total"));
        assertEquals("CONFIRMED", list.get(0).get("status"));
    }
}
