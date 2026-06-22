package com.katasticho.erp.procurement.service;

import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.procurement.dto.CreateStockReceiptRequest;
import com.katasticho.erp.procurement.dto.StockReceiptResponse;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.repository.StockReceiptLineRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyIterable;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PurchaseOrderP2PTest {

    @Mock private PurchaseOrderRepository poRepository;
    @Mock private PurchaseOrderLineRepository lineRepository;
    @Mock private SupplierRepository supplierRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private StockReceiptLineRepository stockReceiptLineRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private StockReceiptService stockReceiptService;
    @Mock private PurchaseBillService purchaseBillService;

    private PurchaseOrderService poService;
    private UUID orgId;
    private Supplier supplier;
    private Item itemA;
    private Item itemB;

    @BeforeEach
    void setUp() {
        poService = new PurchaseOrderService(
                poRepository, lineRepository, supplierRepository, itemRepository,
                stockReceiptLineRepository, contactRepository,
                stockReceiptService, purchaseBillService);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        supplier = Supplier.builder().name("Acme Distributors").stateCode("MH").build();
        supplier.setId(UUID.randomUUID());
        supplier.setOrgId(orgId);

        itemA = Item.builder().sku("ITEM-A").name("Widget A")
                .itemType(ItemType.GOODS).unitOfMeasure("PCS").gstRate(new BigDecimal("18"))
                .hsnCode("8473").trackInventory(true).build();
        itemA.setId(UUID.randomUUID());
        itemA.setOrgId(orgId);

        itemB = Item.builder().sku("ITEM-B").name("Widget B")
                .itemType(ItemType.GOODS).unitOfMeasure("PCS").gstRate(new BigDecimal("12"))
                .hsnCode("8474").trackInventory(true).build();
        itemB.setId(UUID.randomUUID());
        itemB.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void createGrnFromPo_drafts_with_remaining_quantities_and_fk_links() {
        PurchaseOrder po = PurchaseOrder.builder()
                .orgId(orgId).supplierId(supplier.getId()).poNumber("PO-00001")
                .status("SENT").orderDate(LocalDate.of(2026, 6, 1))
                .warehouseId(UUID.randomUUID()).build();
        po.setId(UUID.randomUUID());

        PurchaseOrderLine pol1 = PurchaseOrderLine.builder()
                .poId(po.getId()).itemId(itemA.getId())
                .quantity(new BigDecimal("100")).receivedQuantity(BigDecimal.ZERO)
                .unitPrice(new BigDecimal("50")).lineTotal(new BigDecimal("5000")).build();
        pol1.setId(UUID.randomUUID());
        PurchaseOrderLine pol2 = PurchaseOrderLine.builder()
                .poId(po.getId()).itemId(itemB.getId())
                .quantity(new BigDecimal("50")).receivedQuantity(BigDecimal.ZERO)
                .unitPrice(new BigDecimal("80")).lineTotal(new BigDecimal("4000")).build();
        pol2.setId(UUID.randomUUID());

        when(poRepository.findByIdAndOrgIdAndIsDeletedFalse(po.getId(), orgId))
                .thenReturn(Optional.of(po));
        when(lineRepository.findByPoId(po.getId())).thenReturn(List.of(pol1, pol2));
        // 30 already received on the first line; the second hasn't been received yet.
        when(stockReceiptLineRepository.sumQuantityForPurchaseOrderLine(pol1.getId()))
                .thenReturn(new BigDecimal("30"));
        when(stockReceiptLineRepository.sumQuantityForPurchaseOrderLine(pol2.getId()))
                .thenReturn(BigDecimal.ZERO);
        when(itemRepository.findAllById(anyIterable())).thenReturn(List.of(itemA, itemB));

        when(stockReceiptService.createDraft(any(CreateStockReceiptRequest.class)))
                .thenAnswer(inv -> {
                    CreateStockReceiptRequest req = inv.getArgument(0);
                    // verify the request shape inside the answer for easier debugging
                    return new StockReceiptResponse(
                            UUID.randomUUID(), "GRN-00001", req.receiptDate(),
                            req.warehouseId(), "Main", req.supplierId(), supplier.getName(), null,
                            null, null, "DRAFT",
                            BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                            BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                            "INR", null, req.purchaseOrderId(), List.of(),
                            null, null, null, null);
                });

        StockReceiptResponse response = poService.createGrnFromPo(po.getId());

        assertNotNull(response);
        assertEquals(po.getId(), response.purchaseOrderId());

        ArgumentCaptor<CreateStockReceiptRequest> captor =
                ArgumentCaptor.forClass(CreateStockReceiptRequest.class);
        org.mockito.Mockito.verify(stockReceiptService).createDraft(captor.capture());
        CreateStockReceiptRequest req = captor.getValue();
        assertEquals(po.getId(), req.purchaseOrderId(), "GRN must link to the source PO");
        assertEquals(po.getWarehouseId(), req.warehouseId());
        assertEquals(2, req.lines().size());
        // First line: 100 ordered − 30 received = 70 remaining; FK set on the line
        assertEquals(0, new BigDecimal("70.0000").compareTo(req.lines().get(0).quantity()));
        assertEquals(pol1.getId(), req.lines().get(0).purchaseOrderLineId());
        assertEquals(itemA.getHsnCode(), req.lines().get(0).hsnCode());
        assertEquals(0, new BigDecimal("18").compareTo(req.lines().get(0).gstRate()));
        // Second line: full 50 carry through
        assertEquals(0, new BigDecimal("50.0000").compareTo(req.lines().get(1).quantity()));
        assertEquals(pol2.getId(), req.lines().get(1).purchaseOrderLineId());
    }

    @Test
    void createBillFromPo_drafts_with_fk_links_and_po_prices() {
        PurchaseOrder po = PurchaseOrder.builder()
                .orgId(orgId).supplierId(supplier.getId()).poNumber("PO-00002")
                .status("SENT").orderDate(LocalDate.of(2026, 6, 1)).build();
        po.setId(UUID.randomUUID());

        PurchaseOrderLine pol1 = PurchaseOrderLine.builder()
                .poId(po.getId()).itemId(itemA.getId())
                .description("Widget A").quantity(new BigDecimal("100"))
                .receivedQuantity(BigDecimal.ZERO)
                .unitPrice(new BigDecimal("50")).lineTotal(new BigDecimal("5000")).build();
        pol1.setId(UUID.randomUUID());

        Contact vendor = Contact.builder().displayName("Acme Distributors")
                .contactType(ContactType.VENDOR).build();
        vendor.setId(UUID.randomUUID());
        vendor.setOrgId(orgId);

        when(poRepository.findByIdAndOrgIdAndIsDeletedFalse(po.getId(), orgId))
                .thenReturn(Optional.of(po));
        when(supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(supplier.getId(), orgId))
                .thenReturn(Optional.of(supplier));
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(
                orgId, supplier.getName())).thenReturn(Optional.of(vendor));
        when(lineRepository.findByPoId(po.getId())).thenReturn(List.of(pol1));
        when(itemRepository.findAllById(anyIterable())).thenReturn(List.of(itemA));

        when(purchaseBillService.createBill(any(CreatePurchaseBillRequest.class)))
                .thenAnswer(inv -> {
                    CreatePurchaseBillRequest req = inv.getArgument(0);
                    return new PurchaseBillResponse(
                            UUID.randomUUID(), req.contactId(), vendor.getDisplayName(),
                            "BILL-2026-00001", null,
                            req.billDate(), req.billDate().plusDays(30), "DRAFT",
                            new BigDecimal("5000"), new BigDecimal("900"), new BigDecimal("5900"),
                            BigDecimal.ZERO, new BigDecimal("5900"), BigDecimal.ZERO,
                            "INR", null, false, null, req.purchaseOrderId(), req.notes(),
                            List.of(), java.time.Instant.now());
                });

        PurchaseBillResponse bill = poService.createBillFromPo(po.getId());

        assertNotNull(bill);
        assertEquals(po.getId(), bill.purchaseOrderId());

        ArgumentCaptor<CreatePurchaseBillRequest> captor =
                ArgumentCaptor.forClass(CreatePurchaseBillRequest.class);
        org.mockito.Mockito.verify(purchaseBillService).createBill(captor.capture());
        CreatePurchaseBillRequest req = captor.getValue();
        assertEquals(po.getId(), req.purchaseOrderId());
        assertEquals(vendor.getId(), req.contactId());
        assertEquals(1, req.lines().size());
        var billLine = req.lines().get(0);
        assertEquals(pol1.getId(), billLine.purchaseOrderLineId(), "Bill line must FK back to PO line");
        assertEquals(0, new BigDecimal("100").compareTo(billLine.quantity()));
        assertEquals(0, new BigDecimal("50").compareTo(billLine.unitPrice()));
        assertEquals(itemA.getHsnCode(), billLine.hsnCode());
    }

    @Test
    void createGrnFromPo_throws_when_fully_received() {
        PurchaseOrder po = PurchaseOrder.builder()
                .orgId(orgId).supplierId(supplier.getId()).poNumber("PO-00003")
                .status("SENT").orderDate(LocalDate.of(2026, 6, 1))
                .warehouseId(UUID.randomUUID()).build();
        po.setId(UUID.randomUUID());

        PurchaseOrderLine pol1 = PurchaseOrderLine.builder()
                .poId(po.getId()).itemId(itemA.getId())
                .quantity(new BigDecimal("100")).receivedQuantity(new BigDecimal("100"))
                .unitPrice(new BigDecimal("50")).lineTotal(new BigDecimal("5000")).build();
        pol1.setId(UUID.randomUUID());

        when(poRepository.findByIdAndOrgIdAndIsDeletedFalse(po.getId(), orgId))
                .thenReturn(Optional.of(po));
        when(lineRepository.findByPoId(po.getId())).thenReturn(List.of(pol1));
        when(stockReceiptLineRepository.sumQuantityForPurchaseOrderLine(pol1.getId()))
                .thenReturn(new BigDecimal("100"));
        when(itemRepository.findAllById(anyIterable())).thenReturn(List.of(itemA));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> poService.createGrnFromPo(po.getId()));
        assertEquals("PO_FULLY_RECEIVED", ex.getErrorCode());
        org.mockito.Mockito.verifyNoInteractions(stockReceiptService);
    }
}
