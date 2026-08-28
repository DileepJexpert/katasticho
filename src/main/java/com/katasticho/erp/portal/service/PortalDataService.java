package com.katasticho.erp.portal.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.dto.ContactLedgerResponse;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.portal.entity.PortalUser;
import com.katasticho.erp.portal.repository.PortalUserRepository;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.pricing.dto.SchemeResponse;
import com.katasticho.erp.pricing.service.PriceListService;
import com.katasticho.erp.pricing.service.SchemeService;
import com.katasticho.erp.sales.dto.CreateSalesOrderRequest;
import com.katasticho.erp.sales.dto.SalesOrderLineRequest;
import com.katasticho.erp.sales.dto.SalesOrderResponse;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.sales.service.SalesOrderService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Read-only and retailer reorder data for a logged-in portal user, scoped to THEIR contact only.
 * The portal filter sets {@code TenantContext} (orgId + userId=portalUserId);
 * this resolves the {@link PortalUser} to get the contact and kind, then serves
 * customer (invoices/outstanding/catalog/orders/ledger) or vendor (POs/bills) data.
 */
@Service
@RequiredArgsConstructor
public class PortalDataService {

    private final PortalUserRepository portalUserRepository;
    private final ContactRepository contactRepository;
    private final InvoiceRepository invoiceRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final PurchaseOrderRepository purchaseOrderRepository;
    private final ContactLedgerService contactLedgerService;
    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final PriceListService priceListService;
    private final SchemeService schemeService;
    private final SalesOrderRepository salesOrderRepository;
    private final SalesOrderService salesOrderService;

    @Transactional(readOnly = true)
    public Map<String, Object> me() {
        PortalUser pu = current();
        Contact contact = contact(pu);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("kind", pu.getKind());
        out.put("email", pu.getEmail());
        out.put("fullName", pu.getFullName());
        out.put("contact", contactSummary(contact));
        return out;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> dashboard() {
        PortalUser pu = current();
        if ("VENDOR".equals(pu.getKind())) {
            return vendorDashboard(pu);
        }
        return customerDashboard(pu);
    }

    // ── Customer ─────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<Map<String, Object>> invoices() {
        PortalUser pu = customerOnly();
        return invoiceRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 100))
                .getContent().stream().map(this::invoiceRow).toList();
    }

    @Transactional(readOnly = true)
    public ContactLedgerResponse statement(LocalDate from, LocalDate to) {
        PortalUser pu = customerOnly();
        return contactLedgerService.getLedger(pu.getContactId(), from, to);
    }

    private Map<String, Object> customerDashboard(PortalUser pu) {
        List<Invoice> invoices = invoiceRepository
                .findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 500))
                .getContent();
        BigDecimal outstanding = BigDecimal.ZERO;
        int openCount = 0;
        for (Invoice inv : invoices) {
            BigDecimal bal = nz(inv.getBalanceDue());
            if (bal.signum() > 0) openCount++;
            outstanding = outstanding.add(bal);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("kind", "CUSTOMER");
        out.put("outstanding", outstanding);
        out.put("openInvoiceCount", openCount);
        out.put("totalInvoiceCount", invoices.size());
        out.put("recentInvoices", invoices.stream().limit(5).map(this::invoiceRow).toList());
        return out;
    }

    // ── Vendor ───────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<Map<String, Object>> purchaseOrders() {
        PortalUser pu = vendorOnly();
        return purchaseOrderRepository
                .findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByCreatedAtDesc(pu.getOrgId(), pu.getContactId())
                .stream().map(this::poRow).toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> bills() {
        PortalUser pu = vendorOnly();
        return purchaseBillRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 100))
                .getContent().stream().map(this::billRow).toList();
    }

    private Map<String, Object> vendorDashboard(PortalUser pu) {
        List<PurchaseOrder> pos = purchaseOrderRepository
                .findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByCreatedAtDesc(pu.getOrgId(), pu.getContactId());
        List<PurchaseBill> billList = purchaseBillRepository
                .findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 500))
                .getContent();
        BigDecimal payable = BigDecimal.ZERO;
        int unpaid = 0;
        for (PurchaseBill b : billList) {
            BigDecimal bal = nz(b.getBalanceDue());
            if (bal.signum() > 0) unpaid++;
            payable = payable.add(bal);
        }
        long openPos = pos.stream()
                .filter(p -> !"CANCELLED".equalsIgnoreCase(p.getStatus())
                        && !"CLOSED".equalsIgnoreCase(p.getStatus())
                        && !"COMPLETED".equalsIgnoreCase(p.getStatus()))
                .count();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("kind", "VENDOR");
        out.put("payableToYou", payable);
        out.put("unpaidBillCount", unpaid);
        out.put("openPurchaseOrderCount", openPos);
        out.put("recentPurchaseOrders", pos.stream().limit(5).map(this::poRow).toList());
        return out;
    }

    // ── Retailer Quick Reorder & Orders (Customer) ──────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> catalog(String search, String category, int page, int size) {
        PortalUser pu = customerOnly();
        UUID orgId = pu.getOrgId();
        UUID contactId = pu.getContactId();

        Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(Math.max(1, size), 100));
        Page<Item> itemPage;
        if (search != null && !search.isBlank()) {
            itemPage = itemRepository.search(orgId, search.trim(), pageable);
        } else {
            itemPage = itemRepository.findByOrgIdAndIsDeletedFalseAndActiveTrue(orgId, pageable);
        }

        List<UUID> itemIds = itemPage.getContent().stream().map(Item::getId).toList();
        Map<UUID, BigDecimal> stockMap = new HashMap<>();
        if (!itemIds.isEmpty()) {
            List<StockBalance> balances = stockBalanceRepository.findByOrgIdAndItemIdIn(orgId, itemIds);
            for (StockBalance b : balances) {
                stockMap.merge(b.getItemId(), nz(b.getQuantityOnHand()), BigDecimal::add);
            }
        }

        List<Map<String, Object>> items = itemPage.getContent().stream()
                .filter(i -> category == null || category.isBlank() || (i.getCategory() != null && i.getCategory().equalsIgnoreCase(category.trim())))
                .map(item -> formatCatalogItem(item, contactId, stockMap.getOrDefault(item.getId(), BigDecimal.ZERO)))
                .toList();

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("items", items);
        out.put("page", itemPage.getNumber());
        out.put("size", itemPage.getSize());
        out.put("totalElements", itemPage.getTotalElements());
        out.put("totalPages", itemPage.getTotalPages());
        return out;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> frequentItems() {
        PortalUser pu = customerOnly();
        UUID orgId = pu.getOrgId();
        UUID contactId = pu.getContactId();

        Page<SalesOrder> recentOrders = salesOrderRepository
                .findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId, PageRequest.of(0, 10));
        
        Set<UUID> frequentItemIds = new LinkedHashSet<>();
        for (SalesOrder so : recentOrders.getContent()) {
            for (SalesOrderLine line : so.getLines()) {
                if (line.getItemId() != null) {
                    frequentItemIds.add(line.getItemId());
                    if (frequentItemIds.size() >= 10) break;
                }
            }
            if (frequentItemIds.size() >= 10) break;
        }

        List<Item> items;
        if (!frequentItemIds.isEmpty()) {
            items = itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, frequentItemIds);
        } else {
            items = itemRepository.findByOrgIdAndIsDeletedFalseAndActiveTrue(orgId, PageRequest.of(0, 6)).getContent();
        }

        List<UUID> itemIds = items.stream().map(Item::getId).toList();
        Map<UUID, BigDecimal> stockMap = new HashMap<>();
        if (!itemIds.isEmpty()) {
            List<StockBalance> balances = stockBalanceRepository.findByOrgIdAndItemIdIn(orgId, itemIds);
            for (StockBalance b : balances) {
                stockMap.merge(b.getItemId(), nz(b.getQuantityOnHand()), BigDecimal::add);
            }
        }

        return items.stream()
                .map(item -> formatCatalogItem(item, contactId, stockMap.getOrDefault(item.getId(), BigDecimal.ZERO)))
                .toList();
    }

    @Transactional
    public Map<String, Object> placeOrder(Map<String, Object> req) {
        PortalUser pu = customerOnly();
        UUID orgId = pu.getOrgId();
        UUID contactId = pu.getContactId();

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> lineInputs = (List<Map<String, Object>>) req.get("lines");
        if (lineInputs == null || lineInputs.isEmpty()) {
            throw new BusinessException("Order must contain at least one line item",
                    "PORTAL_ORDER_EMPTY", HttpStatus.BAD_REQUEST);
        }

        String notes = (String) req.get("notes");
        String referenceNumber = (String) req.get("referenceNumber");
        String shipmentDateStr = (String) req.get("expectedShipmentDate");
        LocalDate shipmentDate = shipmentDateStr != null && !shipmentDateStr.isBlank()
                ? LocalDate.parse(shipmentDateStr) : LocalDate.now().plusDays(1);

        List<SalesOrderLineRequest> lines = new ArrayList<>();
        for (Map<String, Object> lineMap : lineInputs) {
            UUID itemId = UUID.fromString(lineMap.get("itemId").toString());
            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", itemId));

            BigDecimal qty = new BigDecimal(lineMap.get("quantity").toString());
            if (qty.compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }

            BigDecimal rate = priceListService.resolvePrice(contactId, item.getId(), qty)
                    .orElse(nz(item.getSalePrice()));

            BigDecimal discountPct = BigDecimal.ZERO;
            List<SchemeResponse> applicableSchemes = schemeService.getApplicable(item.getId(), qty);
            if (!applicableSchemes.isEmpty()) {
                SchemeResponse top = applicableSchemes.get(0);
                if ("PERCENT_DISCOUNT".equalsIgnoreCase(top.schemeType()) && top.discountPercent() != null) {
                    discountPct = top.discountPercent();
                }
            }

            lines.add(new SalesOrderLineRequest(
                    item.getId(),
                    item.getName(),
                    qty,
                    rate,
                    item.getUnitOfMeasure(),
                    discountPct,
                    item.getDefaultTaxGroupId(),
                    item.getHsnCode(),
                    item.getGstRate()
            ));
        }

        if (lines.isEmpty()) {
            throw new BusinessException("No valid lines to place order",
                    "PORTAL_ORDER_NO_VALID_LINES", HttpStatus.BAD_REQUEST);
        }

        CreateSalesOrderRequest createReq = new CreateSalesOrderRequest(
                contactId,
                lines,
                LocalDate.now(),
                shipmentDate,
                referenceNumber != null && !referenceNumber.isBlank() ? referenceNumber : "PORTAL-ORD",
                "ITEM_LEVEL",
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                null,
                "STANDARD",
                null,
                notes != null && !notes.isBlank() ? "Portal Order: " + notes : "Placed via Retailer Portal",
                "Payment on Delivery / Normal Terms",
                null,
                null,
                true,
                null
        );

        SalesOrderResponse createdSo = salesOrderService.create(createReq);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", createdSo.id());
        result.put("salesorderNumber", createdSo.salesOrderNumber());
        result.put("orderDate", createdSo.orderDate());
        result.put("total", createdSo.totalAmount());
        result.put("status", createdSo.status());
        result.put("itemCount", lines.size());
        result.put("message", "Order placed successfully! Reference: " + createdSo.salesOrderNumber());
        return result;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> orders() {
        PortalUser pu = customerOnly();
        return salesOrderRepository
                .findByOrgIdAndContactIdAndIsDeletedFalse(pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 100))
                .getContent().stream()
                .map(this::orderRow)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> orderDetail(UUID id) {
        PortalUser pu = customerOnly();
        SalesOrder so = salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(id, pu.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("SalesOrder", id));
        if (!so.getContactId().equals(pu.getContactId())) {
            throw new BusinessException("Access denied to this order", "PORTAL_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
        return orderDetailRow(so);
    }

    private Map<String, Object> formatCatalogItem(Item item, UUID contactId, BigDecimal stockOnHand) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", item.getId());
        m.put("name", item.getName());
        m.put("sku", item.getSku());
        m.put("brand", item.getBrand());
        m.put("category", item.getCategory());
        m.put("composition", item.getComposition());
        m.put("packSize", item.getPackSize());
        m.put("unitOfMeasure", item.getUnitOfMeasure());
        m.put("mrp", item.getMrp() != null ? item.getMrp() : item.getSalePrice());
        
        BigDecimal resolvedRate = priceListService
                .resolvePrice(contactId, item.getId(), BigDecimal.ONE)
                .orElse(nz(item.getSalePrice()));
        m.put("salePrice", resolvedRate);
        m.put("gstRate", nz(item.getGstRate()));
        
        boolean inStock = !item.isTrackInventory() || stockOnHand.compareTo(BigDecimal.ZERO) > 0;
        m.put("trackInventory", item.isTrackInventory());
        m.put("inStock", inStock);
        m.put("stockQuantity", stockOnHand);
        
        List<SchemeResponse> schemes = schemeService.getApplicable(item.getId(), BigDecimal.ONE);
        if (!schemes.isEmpty()) {
            SchemeResponse top = schemes.get(0);
            String desc = top.name();
            if ("BUY_X_GET_Y".equalsIgnoreCase(top.schemeType()) && top.buyQuantity() != null && top.freeQuantity() != null) {
                desc = "Buy " + top.buyQuantity().stripTrailingZeros().toPlainString() + " Get " + top.freeQuantity().stripTrailingZeros().toPlainString() + " Free";
            } else if ("PERCENT_DISCOUNT".equalsIgnoreCase(top.schemeType()) && top.discountPercent() != null) {
                desc = top.discountPercent().stripTrailingZeros().toPlainString() + "% Discount";
            }
            m.put("schemeDescription", desc);
            m.put("schemeType", top.schemeType());
            m.put("schemeDiscountPercent", top.discountPercent());
        } else {
            m.put("schemeDescription", null);
            m.put("schemeType", null);
            m.put("schemeDiscountPercent", BigDecimal.ZERO);
        }
        return m;
    }

    private Map<String, Object> orderRow(SalesOrder so) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", so.getId());
        m.put("number", so.getSalesorderNumber());
        m.put("referenceNumber", so.getReferenceNumber());
        m.put("date", so.getOrderDate());
        m.put("expectedShipmentDate", so.getExpectedShipmentDate());
        m.put("total", nz(so.getTotal()));
        m.put("subtotal", nz(so.getSubtotal()));
        m.put("taxAmount", nz(so.getTaxAmount()));
        m.put("status", so.getStatus());
        m.put("shippedStatus", so.getShippedStatus());
        m.put("invoicedStatus", so.getInvoicedStatus());
        m.put("itemCount", so.getLines().size());
        return m;
    }

    private Map<String, Object> orderDetailRow(SalesOrder so) {
        Map<String, Object> m = orderRow(so);
        m.put("notes", so.getNotes());
        m.put("deliveryMethod", so.getDeliveryMethod());
        List<Map<String, Object>> lineList = so.getLines().stream().map(l -> {
            Map<String, Object> lm = new LinkedHashMap<>();
            lm.put("id", l.getId());
            lm.put("itemId", l.getItemId());
            lm.put("description", l.getDescription());
            lm.put("quantity", nz(l.getQuantity()));
            lm.put("quantityShipped", nz(l.getQuantityShipped()));
            lm.put("quantityInvoiced", nz(l.getQuantityInvoiced()));
            lm.put("unit", l.getUnit());
            lm.put("rate", nz(l.getRate()));
            lm.put("discountPct", nz(l.getDiscountPct()));
            lm.put("taxRate", nz(l.getTaxRate()));
            lm.put("amount", nz(l.getAmount()));
            return lm;
        }).toList();
        m.put("lines", lineList);
        return m;
    }

    // ── Row mappers ──────────────────────────────────────────────────────

    private Map<String, Object> invoiceRow(Invoice inv) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", inv.getId());
        m.put("number", inv.getInvoiceNumber());
        m.put("date", inv.getInvoiceDate());
        m.put("dueDate", inv.getDueDate());
        m.put("total", nz(inv.getTotalAmount()));
        m.put("balanceDue", nz(inv.getBalanceDue()));
        m.put("status", inv.getStatus());
        return m;
    }

    private Map<String, Object> billRow(PurchaseBill b) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", b.getId());
        m.put("number", b.getBillNumber());
        m.put("vendorBillNumber", b.getVendorBillNumber());
        m.put("date", b.getBillDate());
        m.put("dueDate", b.getDueDate());
        m.put("total", nz(b.getTotalAmount()));
        m.put("balanceDue", nz(b.getBalanceDue()));
        m.put("status", b.getStatus());
        return m;
    }

    private Map<String, Object> poRow(PurchaseOrder p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId());
        m.put("number", p.getPoNumber());
        m.put("date", p.getOrderDate());
        m.put("total", nz(p.getTotalAmount()));
        m.put("status", p.getStatus());
        return m;
    }

    private Map<String, Object> contactSummary(Contact c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.getId());
        m.put("displayName", c.getDisplayName());
        m.put("email", c.getEmail());
        m.put("phone", c.getPhone() != null ? c.getPhone() : c.getMobile());
        return m;
    }

    // ── Scoping helpers ──────────────────────────────────────────────────

    private PortalUser current() {
        UUID portalUserId = TenantContext.getCurrentUserId();
        return portalUserRepository.findByIdAndIsDeletedFalse(portalUserId)
                .filter(p -> "ACTIVE".equals(p.getStatus()))
                .orElseThrow(() -> new BusinessException("Portal session is invalid",
                        "PORTAL_SESSION_INVALID", HttpStatus.UNAUTHORIZED));
    }

    private PortalUser customerOnly() {
        PortalUser pu = current();
        if (!"CUSTOMER".equals(pu.getKind())) {
            throw new BusinessException("Not available for vendor accounts",
                    "PORTAL_WRONG_KIND", HttpStatus.FORBIDDEN);
        }
        return pu;
    }

    private PortalUser vendorOnly() {
        PortalUser pu = current();
        if (!"VENDOR".equals(pu.getKind())) {
            throw new BusinessException("Not available for customer accounts",
                    "PORTAL_WRONG_KIND", HttpStatus.FORBIDDEN);
        }
        return pu;
    }

    private Contact contact(PortalUser pu) {
        return contactRepository.findByIdAndOrgIdAndIsDeletedFalse(pu.getContactId(), pu.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Contact", pu.getContactId()));
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
