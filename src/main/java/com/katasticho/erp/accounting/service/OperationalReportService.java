package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.report.OperationalReportResponse;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import com.katasticho.erp.sales.entity.DeliveryChallan;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class OperationalReportService {

    private final OrganisationRepository organisationRepository;
    private final InvoiceRepository invoiceRepository;
    private final SalesReceiptRepository salesReceiptRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final JournalEntryRepository journalEntryRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final StockMovementRepository stockMovementRepository;
    private final ContactRepository contactRepository;
    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final StockBatchRepository stockBatchRepository;
    private final SalesOrderRepository salesOrderRepository;
    private final DeliveryChallanRepository deliveryChallanRepository;

    public OperationalReportResponse salesRegister(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<Invoice> invoices = invoiceRepository.findPostedByOrgAndDateRange(ctx.orgId(), startDate, endDate);
        Map<UUID, String> contacts = contactNames(ctx.orgId(), invoices.stream().map(Invoice::getContactId).toList());

        List<Map<String, Object>> rows = invoices.stream()
                .map(i -> row(
                        "date", i.getInvoiceDate(),
                        "number", i.getInvoiceNumber(),
                        "customer", contacts.getOrDefault(i.getContactId(), "Unknown"),
                        "status", i.getStatus(),
                        "taxable", nz(i.getSubtotal()),
                        "tax", nz(i.getTaxAmount()),
                        "total", nz(i.getTotalAmount()),
                        "balance", nz(i.getBalanceDue()),
                        "source", "Invoice",
                        "sourceId", i.getId()
                ))
                .toList();

        BigDecimal taxable = sum(invoices, Invoice::getSubtotal);
        BigDecimal tax = sum(invoices, Invoice::getTaxAmount);
        BigDecimal total = sum(invoices, Invoice::getTotalAmount);
        BigDecimal balance = sum(invoices, Invoice::getBalanceDue);

        return response("sales-register", "Sales Register",
                "Posted credit invoices for the selected period.",
                startDate, endDate, ctx.currency(),
                metrics(metric("count", "Invoices", BigDecimal.valueOf(invoices.size()), "number"),
                        metric("taxable", "Taxable Sales", taxable, "currency"),
                        metric("tax", "Output GST", tax, "currency"),
                        metric("total", "Invoice Total", total, "currency"),
                        metric("balance", "Outstanding", balance, "currency")),
                columns(col("date", "Date", "date"), col("number", "Invoice", "text"),
                        col("customer", "Customer", "text"), col("status", "Status", "status"),
                        col("taxable", "Taxable", "currency"), col("tax", "GST", "currency"),
                        col("total", "Total", "currency"), col("balance", "Balance", "currency")),
                rows);
    }

    public OperationalReportResponse dailySales(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<SalesReceipt> receipts = salesReceiptRepository.findByOrgAndDateRange(ctx.orgId(), startDate, endDate);
        List<Invoice> invoices = invoiceRepository.findPostedByOrgAndDateRange(ctx.orgId(), startDate, endDate);
        Map<UUID, String> contacts = contactNames(ctx.orgId(), invoices.stream().map(Invoice::getContactId).toList());

        List<Map<String, Object>> rows = new ArrayList<>();
        receipts.forEach(r -> rows.add(row(
                "date", r.getReceiptDate(),
                "number", r.getReceiptNumber(),
                "customer", "Walk-in",
                "mode", String.valueOf(r.getPaymentMode()),
                "taxable", nz(r.getSubtotal()),
                "tax", nz(r.getTaxAmount()),
                "total", nz(r.getTotal()),
                "source", "POS",
                "sourceId", r.getId()
        )));
        invoices.forEach(i -> rows.add(row(
                "date", i.getInvoiceDate(),
                "number", i.getInvoiceNumber(),
                "customer", contacts.getOrDefault(i.getContactId(), "Unknown"),
                "mode", "Credit",
                "taxable", nz(i.getSubtotal()),
                "tax", nz(i.getTaxAmount()),
                "total", nz(i.getTotalAmount()),
                "source", "Invoice",
                "sourceId", i.getId()
        )));
        rows.sort(Comparator.comparing(r -> String.valueOf(r.get("date")), Comparator.reverseOrder()));

        BigDecimal posTotal = sum(receipts, SalesReceipt::getTotal);
        BigDecimal creditTotal = sum(invoices, Invoice::getTotalAmount);
        BigDecimal total = posTotal.add(creditTotal);
        BigDecimal tax = sum(receipts, SalesReceipt::getTaxAmount).add(sum(invoices, Invoice::getTaxAmount));

        return response("daily-sales", "Daily Sales Summary",
                "POS receipts and posted invoices in one sales view.",
                startDate, endDate, ctx.currency(),
                metrics(metric("transactions", "Transactions", BigDecimal.valueOf(rows.size()), "number"),
                        metric("pos", "Cash/UPI/Card Sales", posTotal, "currency"),
                        metric("credit", "Credit Sales", creditTotal, "currency"),
                        metric("tax", "Output GST", tax, "currency"),
                        metric("total", "Total Sales", total, "currency")),
                columns(col("date", "Date", "date"), col("number", "Document", "text"),
                        col("customer", "Customer", "text"), col("mode", "Mode", "text"),
                        col("taxable", "Taxable", "currency"), col("tax", "GST", "currency"),
                        col("total", "Total", "currency"), col("source", "Source", "text")),
                rows);
    }

    public OperationalReportResponse purchaseRegister(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<PurchaseBill> bills = purchaseBillRepository.findPostedByOrgAndDateRange(ctx.orgId(), startDate, endDate);
        Map<UUID, String> contacts = contactNames(ctx.orgId(), bills.stream().map(PurchaseBill::getContactId).toList());

        List<Map<String, Object>> rows = bills.stream()
                .map(b -> row(
                        "date", b.getBillDate(),
                        "number", b.getBillNumber(),
                        "vendorBill", b.getVendorBillNumber(),
                        "vendor", contacts.getOrDefault(b.getContactId(), "Unknown"),
                        "status", b.getStatus(),
                        "taxable", nz(b.getSubtotal()),
                        "tax", nz(b.getTaxAmount()),
                        "tds", nz(b.getTdsAmount()),
                        "total", nz(b.getTotalAmount()),
                        "balance", nz(b.getBalanceDue()),
                        "sourceId", b.getId()
                ))
                .toList();

        return response("purchase-register", "Purchase Register",
                "Posted vendor bills for the selected period.",
                startDate, endDate, ctx.currency(),
                metrics(metric("count", "Bills", BigDecimal.valueOf(bills.size()), "number"),
                        metric("taxable", "Taxable Purchases", sum(bills, PurchaseBill::getSubtotal), "currency"),
                        metric("tax", "Input GST", sum(bills, PurchaseBill::getTaxAmount), "currency"),
                        metric("tds", "TDS", sum(bills, PurchaseBill::getTdsAmount), "currency"),
                        metric("total", "Bill Total", sum(bills, PurchaseBill::getTotalAmount), "currency")),
                columns(col("date", "Date", "date"), col("number", "Bill", "text"),
                        col("vendorBill", "Vendor Ref", "text"), col("vendor", "Vendor", "text"),
                        col("status", "Status", "status"), col("taxable", "Taxable", "currency"),
                        col("tax", "GST", "currency"), col("tds", "TDS", "currency"),
                        col("total", "Total", "currency"), col("balance", "Balance", "currency")),
                rows);
    }

    public OperationalReportResponse dayBook(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<JournalEntry> entries = journalEntryRepository
                .findByOrgIdAndEffectiveDateBetweenOrderByEffectiveDateDescCreatedAtDesc(ctx.orgId(), startDate, endDate);

        List<Map<String, Object>> rows = entries.stream()
                .map(e -> row(
                        "date", e.getEffectiveDate(),
                        "number", e.getEntryNumber(),
                        "source", e.getSourceModule(),
                        "description", e.getDescription(),
                        "status", e.getStatus(),
                        "entryId", e.getId(),
                        "sourceId", e.getSourceId()
                ))
                .toList();

        return response("day-book", "Day Book",
                "Chronological book of posted and manual accounting events.",
                startDate, endDate, ctx.currency(),
                metrics(metric("entries", "Journal Entries", BigDecimal.valueOf(entries.size()), "number")),
                columns(col("date", "Date", "date"), col("number", "Journal", "text"),
                        col("source", "Source", "text"), col("description", "Description", "text"),
                        col("status", "Status", "status")),
                rows);
    }

    public OperationalReportResponse stockSummary() {
        Context ctx = context();
        List<Item> trackableItems = itemRepository.findByOrgIdAndIsDeletedFalseAndTrackInventoryTrue(ctx.orgId())
                .stream()
                .filter(Item::isActive)
                .toList();
        List<StockBalance> balances = stockBalanceRepository.findByOrgIdOrderByLastMovementAtDesc(ctx.orgId());
        Map<UUID, Warehouse> warehouses = warehouseMap(balances.stream().map(StockBalance::getWarehouseId).toList());
        Warehouse defaultWarehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(ctx.orgId())
                .orElse(null);

        Map<UUID, List<StockBalance>> balancesByItem = balances.stream()
                .collect(Collectors.groupingBy(StockBalance::getItemId));

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Item item : trackableItems) {
            List<StockBalance> itemBalances = balancesByItem.getOrDefault(item.getId(), List.of());
            if (itemBalances.isEmpty()) {
                BigDecimal reorderLevel = nz(item.getReorderLevel());
                rows.add(row(
                        "sku", item.getSku(),
                        "item", item.getName(),
                        "warehouse", defaultWarehouse == null ? "Default" : defaultWarehouse.getName(),
                        "onHand", BigDecimal.ZERO,
                        "reserved", BigDecimal.ZERO,
                        "available", BigDecimal.ZERO,
                        "averageCost", nz(item.getPurchasePrice()),
                        "stockValue", BigDecimal.ZERO,
                        "reorderLevel", reorderLevel,
                        "lowStock", reorderLevel.compareTo(BigDecimal.ZERO) > 0 ? "Yes" : "No"
                ));
                continue;
            }

            for (StockBalance b : itemBalances) {
                    Warehouse wh = warehouses.get(b.getWarehouseId());
                    BigDecimal stockValue = nz(b.getQuantityOnHand()).multiply(nz(b.getAverageCost()));
                    BigDecimal reorderLevel = nz(item.getReorderLevel());
                    rows.add(row(
                            "sku", item.getSku(),
                            "item", item.getName(),
                            "warehouse", wh == null ? "Unknown" : wh.getName(),
                            "onHand", nz(b.getQuantityOnHand()),
                            "reserved", nz(b.getReservedQty()),
                            "available", nz(b.getQuantityOnHand()).subtract(nz(b.getReservedQty())),
                            "averageCost", nz(b.getAverageCost()),
                            "stockValue", stockValue,
                            "reorderLevel", reorderLevel,
                            "lowStock", nz(b.getQuantityOnHand()).compareTo(reorderLevel) <= 0 ? "Yes" : "No"
                    ));
            }
        }

        BigDecimal value = rows.stream()
                .map(r -> (BigDecimal) r.get("stockValue"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return response("stock-summary", "Stock Summary",
                "Current stock quantity, availability, and valuation by warehouse.",
                LocalDate.now(), LocalDate.now(), ctx.currency(),
                metrics(metric("items", "Stock Rows", BigDecimal.valueOf(rows.size()), "number"),
                        metric("value", "Stock Value", value, "currency")),
                columns(col("sku", "SKU", "text"), col("item", "Item", "text"),
                        col("warehouse", "Warehouse", "text"), col("onHand", "On Hand", "number"),
                        col("reserved", "Reserved", "number"), col("available", "Available", "number"),
                        col("averageCost", "Avg Cost", "currency"), col("stockValue", "Value", "currency"),
                        col("reorderLevel", "Reorder", "number"), col("lowStock", "Low Stock", "text")),
                rows);
    }

    public OperationalReportResponse stockMovement(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<StockMovement> movements = stockMovementRepository
                .findByOrgIdAndMovementDateBetweenOrderByMovementDateDescCreatedAtDesc(ctx.orgId(), startDate, endDate);
        Map<UUID, Item> items = itemMap(ctx.orgId(), movements.stream().map(StockMovement::getItemId).toList());
        Map<UUID, Warehouse> warehouses = warehouseMap(movements.stream().map(StockMovement::getWarehouseId).toList());
        Map<UUID, StockBatch> batches = stockBatchRepository.findAllById(
                        movements.stream()
                                .map(StockMovement::getBatchId)
                                .filter(Objects::nonNull)
                                .toList())
                .stream()
                .collect(Collectors.toMap(StockBatch::getId, Function.identity()));

        List<Map<String, Object>> rows = movements.stream()
                .map(m -> {
                    Item item = items.get(m.getItemId());
                    Warehouse wh = warehouses.get(m.getWarehouseId());
                    StockBatch batch = batches.get(m.getBatchId());
                    return row(
                            "date", m.getMovementDate(),
                            "sku", item == null ? "--" : item.getSku(),
                            "item", item == null ? "Unknown" : item.getName(),
                            "warehouse", wh == null ? "Unknown" : wh.getName(),
                            "batch", batch == null ? null : batch.getBatchNumber(),
                            "expiry", batch == null ? null : batch.getExpiryDate(),
                            "type", String.valueOf(m.getMovementType()),
                            "quantity", nz(m.getQuantity()),
                            "unitCost", nz(m.getUnitCost()),
                            "totalCost", nz(m.getTotalCost()),
                            "reference", m.getReferenceNumber(),
                            "movementId", m.getId()
                    );
                })
                .toList();

        BigDecimal inQty = movements.stream()
                .map(StockMovement::getQuantity)
                .filter(q -> nz(q).compareTo(BigDecimal.ZERO) > 0)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal outQty = movements.stream()
                .map(StockMovement::getQuantity)
                .filter(q -> nz(q).compareTo(BigDecimal.ZERO) < 0)
                .map(BigDecimal::abs)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return response("stock-movement", "Stock Movement",
                "Append-only stock ledger for the selected period.",
                startDate, endDate, ctx.currency(),
                metrics(metric("movements", "Movements", BigDecimal.valueOf(movements.size()), "number"),
                        metric("inQty", "Stock In Qty", inQty, "number"),
                        metric("outQty", "Stock Out Qty", outQty, "number")),
                columns(col("date", "Date", "date"), col("sku", "SKU", "text"),
                        col("item", "Item", "text"), col("warehouse", "Warehouse", "text"),
                        col("batch", "Batch", "text"), col("expiry", "Expiry", "date"),
                        col("type", "Type", "text"), col("quantity", "Qty", "number"),
                        col("unitCost", "Unit Cost", "currency"), col("totalCost", "Total Cost", "currency"),
                        col("reference", "Reference", "text")),
                rows);
    }

    public OperationalReportResponse pendingDispatch() {
        Context ctx = context();
        List<SalesOrder> orders = salesOrderRepository.findPendingDispatch(ctx.orgId());
        Map<UUID, String> contacts = contactNames(ctx.orgId(), orders.stream().map(SalesOrder::getContactId).toList());

        LocalDate today = LocalDate.now();
        List<Map<String, Object>> rows = orders.stream()
                .map(so -> {
                    LocalDate expected = so.getExpectedShipmentDate();
                    long daysWaiting = so.getOrderDate() == null ? 0 : java.time.temporal.ChronoUnit.DAYS.between(so.getOrderDate(), today);
                    return row(
                            "orderDate", so.getOrderDate(),
                            "expectedShipment", expected,
                            "orderNumber", so.getSalesorderNumber(),
                            "customer", contacts.getOrDefault(so.getContactId(), "Unknown"),
                            "status", so.getStatus(),
                            "shippedStatus", so.getShippedStatus(),
                            "invoicedStatus", so.getInvoicedStatus(),
                            "total", nz(so.getTotal()),
                            "daysWaiting", BigDecimal.valueOf(Math.max(daysWaiting, 0)),
                            "sourceId", so.getId()
                    );
                })
                .toList();

        long overdue = orders.stream()
                .filter(so -> so.getExpectedShipmentDate() != null && so.getExpectedShipmentDate().isBefore(today))
                .count();

        return response("pending-dispatch", "Pending Dispatch",
                "Confirmed and backorder sales orders still waiting for dispatch.",
                today, today, ctx.currency(),
                metrics(metric("orders", "Orders", BigDecimal.valueOf(orders.size()), "number"),
                        metric("overdue", "Past Expected Date", BigDecimal.valueOf(overdue), "number"),
                        metric("value", "Order Value", sum(orders, SalesOrder::getTotal), "currency")),
                columns(col("orderDate", "Order Date", "date"), col("expectedShipment", "Expected", "date"),
                        col("orderNumber", "Sales Order", "text"), col("customer", "Customer", "text"),
                        col("status", "Status", "status"), col("shippedStatus", "Shipment", "status"),
                        col("invoicedStatus", "Invoice", "status"), col("total", "Total", "currency"),
                        col("daysWaiting", "Days", "number")),
                rows);
    }

    public OperationalReportResponse challanNotInvoiced() {
        Context ctx = context();
        List<DeliveryChallan> challans = deliveryChallanRepository.findDispatchedNotFullyInvoiced(ctx.orgId());
        Map<UUID, String> contacts = contactNames(ctx.orgId(), challans.stream().map(DeliveryChallan::getContactId).toList());
        Map<UUID, SalesOrder> salesOrders = salesOrderRepository.findAllById(
                        challans.stream().map(DeliveryChallan::getSalesOrderId).filter(Objects::nonNull).toList())
                .stream()
                .collect(Collectors.toMap(SalesOrder::getId, Function.identity()));

        LocalDate today = LocalDate.now();
        List<Map<String, Object>> rows = challans.stream()
                .map(dc -> {
                    SalesOrder so = salesOrders.get(dc.getSalesOrderId());
                    LocalDate dispatchDate = dc.getDispatchDate() != null ? dc.getDispatchDate() : dc.getChallanDate();
                    long daysOpen = dispatchDate == null ? 0 : java.time.temporal.ChronoUnit.DAYS.between(dispatchDate, today);
                    return row(
                            "challanDate", dc.getChallanDate(),
                            "dispatchDate", dc.getDispatchDate(),
                            "challanNumber", dc.getChallanNumber(),
                            "salesOrder", so == null ? null : so.getSalesorderNumber(),
                            "customer", contacts.getOrDefault(dc.getContactId(), "Unknown"),
                            "challanStatus", dc.getStatus(),
                            "invoiceStatus", so == null ? "Unknown" : so.getInvoicedStatus(),
                            "orderTotal", so == null ? BigDecimal.ZERO : nz(so.getTotal()),
                            "daysOpen", BigDecimal.valueOf(Math.max(daysOpen, 0)),
                            "sourceId", dc.getId()
                    );
                })
                .toList();

        BigDecimal orderValue = salesOrders.values().stream()
                .map(SalesOrder::getTotal)
                .map(OperationalReportService::nz)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return response("challan-not-invoiced", "Challan Not Invoiced",
                "Dispatched or delivered challans whose linked sales orders are not fully invoiced.",
                today, today, ctx.currency(),
                metrics(metric("challans", "Challans", BigDecimal.valueOf(challans.size()), "number"),
                        metric("value", "Linked SO Value", orderValue, "currency")),
                columns(col("challanDate", "Challan Date", "date"), col("dispatchDate", "Dispatch Date", "date"),
                        col("challanNumber", "Challan", "text"), col("salesOrder", "Sales Order", "text"),
                        col("customer", "Customer", "text"), col("challanStatus", "Challan Status", "status"),
                        col("invoiceStatus", "Invoice Status", "status"), col("orderTotal", "SO Total", "currency"),
                        col("daysOpen", "Days", "number")),
                rows);
    }

    private Context context() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        return new Context(orgId, org.getBaseCurrency());
    }

    private Map<UUID, String> contactNames(UUID orgId, Collection<UUID> ids) {
        if (ids == null || ids.isEmpty()) return Map.of();
        return contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, ids.stream().filter(Objects::nonNull).toList())
                .stream()
                .collect(Collectors.toMap(Contact::getId, Contact::getDisplayName));
    }

    private Map<UUID, Item> itemMap(UUID orgId, Collection<UUID> ids) {
        if (ids == null || ids.isEmpty()) return Map.of();
        return itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, ids.stream().filter(Objects::nonNull).toList())
                .stream()
                .collect(Collectors.toMap(Item::getId, Function.identity()));
    }

    private Map<UUID, Warehouse> warehouseMap(Collection<UUID> ids) {
        if (ids == null || ids.isEmpty()) return Map.of();
        return warehouseRepository.findAllById(ids.stream().filter(Objects::nonNull).toList())
                .stream()
                .collect(Collectors.toMap(Warehouse::getId, Function.identity()));
    }

    private OperationalReportResponse response(String key, String title, String description,
                                               LocalDate startDate, LocalDate endDate, String currency,
                                               List<OperationalReportResponse.SummaryMetric> metrics,
                                               List<OperationalReportResponse.ColumnDef> columns,
                                               List<Map<String, Object>> rows) {
        return new OperationalReportResponse(key, title, description, startDate, endDate, currency, metrics, columns, rows);
    }

    private List<OperationalReportResponse.SummaryMetric> metrics(OperationalReportResponse.SummaryMetric... metrics) {
        return List.of(metrics);
    }

    private OperationalReportResponse.SummaryMetric metric(String key, String label, BigDecimal value, String format) {
        return new OperationalReportResponse.SummaryMetric(key, label, nz(value), format);
    }

    private OperationalReportResponse.ColumnDef col(String key, String label, String type) {
        return new OperationalReportResponse.ColumnDef(key, label, type);
    }

    private List<OperationalReportResponse.ColumnDef> columns(OperationalReportResponse.ColumnDef... columns) {
        return List.of(columns);
    }

    private Map<String, Object> row(Object... values) {
        Map<String, Object> row = new LinkedHashMap<>();
        for (int i = 0; i < values.length; i += 2) {
            row.put((String) values[i], values[i + 1]);
        }
        return row;
    }

    private <T> BigDecimal sum(Collection<T> rows, Function<T, BigDecimal> mapper) {
        return rows.stream().map(mapper).map(OperationalReportService::nz).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static BigDecimal nz(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private record Context(UUID orgId, String currency) {}
}
