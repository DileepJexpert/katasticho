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
    private final com.katasticho.erp.organisation.OrgSettingsService orgSettingsService;

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

    public OperationalReportResponse cashFlow(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<JournalEntry> entries = journalEntryRepository
                .findByOrgIdAndEffectiveDateBetweenOrderByEffectiveDateDescCreatedAtDesc(ctx.orgId(), startDate, endDate);

        Map<LocalDate, BigDecimal> inflowByDate = new LinkedHashMap<>();
        Map<LocalDate, BigDecimal> outflowByDate = new LinkedHashMap<>();

        for (JournalEntry je : entries) {
            if (!"POSTED".equals(je.getStatus())) continue;
            BigDecimal totalDebit = je.getLines().stream()
                    .map(l -> nz(l.getBaseDebit()))
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal totalCredit = je.getLines().stream()
                    .map(l -> nz(l.getBaseCredit()))
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            if ("SALES".equals(je.getSourceModule()) || "POS".equals(je.getSourceModule())) {
                inflowByDate.merge(je.getEffectiveDate(), totalDebit, BigDecimal::add);
            }
            if ("PURCHASE".equals(je.getSourceModule())) {
                outflowByDate.merge(je.getEffectiveDate(), totalCredit, BigDecimal::add);
            }
        }

        Set<LocalDate> allDates = new TreeSet<>();
        allDates.addAll(inflowByDate.keySet());
        allDates.addAll(outflowByDate.keySet());

        BigDecimal totalInflow = BigDecimal.ZERO;
        BigDecimal totalOutflow = BigDecimal.ZERO;
        List<Map<String, Object>> rows = new ArrayList<>();
        BigDecimal running = BigDecimal.ZERO;
        for (LocalDate date : allDates) {
            BigDecimal inflow = inflowByDate.getOrDefault(date, BigDecimal.ZERO);
            BigDecimal outflow = outflowByDate.getOrDefault(date, BigDecimal.ZERO);
            BigDecimal net = inflow.subtract(outflow);
            running = running.add(net);
            totalInflow = totalInflow.add(inflow);
            totalOutflow = totalOutflow.add(outflow);
            rows.add(row("date", date, "inflow", inflow, "outflow", outflow, "net", net, "balance", running));
        }

        return response("cash-flow", "Cash Flow Statement",
                "Daily operating cash inflows vs outflows from posted journals.",
                startDate, endDate, ctx.currency(),
                metrics(metric("inflow", "Total Inflow", totalInflow, "currency"),
                        metric("outflow", "Total Outflow", totalOutflow, "currency"),
                        metric("net", "Net Cash Flow", totalInflow.subtract(totalOutflow), "currency")),
                columns(col("date", "Date", "date"), col("inflow", "Inflow", "currency"),
                        col("outflow", "Outflow", "currency"), col("net", "Net", "currency"),
                        col("balance", "Running Balance", "currency")),
                rows);
    }

    public OperationalReportResponse journalRegister(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<JournalEntry> entries = journalEntryRepository
                .findByOrgIdAndEffectiveDateBetweenOrderByEffectiveDateDescCreatedAtDesc(ctx.orgId(), startDate, endDate);

        List<Map<String, Object>> rows = entries.stream()
                .map(e -> {
                    BigDecimal totalDebit = e.getLines().stream()
                            .map(l -> nz(l.getBaseDebit()))
                            .reduce(BigDecimal.ZERO, BigDecimal::add);
                    BigDecimal totalCredit = e.getLines().stream()
                            .map(l -> nz(l.getBaseCredit()))
                            .reduce(BigDecimal.ZERO, BigDecimal::add);
                    return row("date", e.getEffectiveDate(),
                            "number", e.getEntryNumber(),
                            "source", e.getSourceModule(),
                            "description", e.getDescription(),
                            "debit", totalDebit,
                            "credit", totalCredit,
                            "status", e.getStatus(),
                            "lineCount", BigDecimal.valueOf(e.getLines().size()));
                })
                .toList();

        BigDecimal grandDebit = rows.stream()
                .map(r -> (BigDecimal) r.get("debit"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return response("journal-register", "Journal Register",
                "All journal entries with totals, filterable by date range.",
                startDate, endDate, ctx.currency(),
                metrics(metric("entries", "Journal Entries", BigDecimal.valueOf(entries.size()), "number"),
                        metric("totalDebit", "Total Debit", grandDebit, "currency")),
                columns(col("date", "Date", "date"), col("number", "Journal #", "text"),
                        col("source", "Source", "text"), col("description", "Description", "text"),
                        col("debit", "Debit", "currency"), col("credit", "Credit", "currency"),
                        col("status", "Status", "status"), col("lineCount", "Lines", "number")),
                rows);
    }

    /**
     * Cost-centre summary: every journal line tagged with a cost centre,
     * grouped by centre with debit/credit/net totals. Untagged lines are
     * summarised in one "(untagged)" row so the report always reconciles to
     * the journal register.
     */
    public OperationalReportResponse costCentres(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<JournalEntry> entries = journalEntryRepository
                .findPostedWithLinesInRange(ctx.orgId(), startDate, endDate);

        record Totals(BigDecimal[] debitCredit, int[] lineCount) {}
        Map<String, Totals> byCentre = new TreeMap<>();
        Function<String, Totals> bucket = key -> byCentre.computeIfAbsent(key,
                k -> new Totals(new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO}, new int[]{0}));

        BigDecimal taggedAmount = BigDecimal.ZERO;
        for (JournalEntry je : entries) {
            for (var line : je.getLines()) {
                String centre = line.getCostCentre();
                boolean tagged = centre != null && !centre.isBlank();
                Totals t = bucket.apply(tagged ? centre.trim() : "(untagged)");
                t.debitCredit()[0] = t.debitCredit()[0].add(nz(line.getBaseDebit()));
                t.debitCredit()[1] = t.debitCredit()[1].add(nz(line.getBaseCredit()));
                t.lineCount()[0]++;
                if (tagged) {
                    taggedAmount = taggedAmount.add(nz(line.getBaseDebit())).add(nz(line.getBaseCredit()));
                }
            }
        }

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Map.Entry<String, Totals> e : byCentre.entrySet()) {
            BigDecimal debit = e.getValue().debitCredit()[0];
            BigDecimal credit = e.getValue().debitCredit()[1];
            rows.add(row("centre", e.getKey(),
                    "debit", debit,
                    "credit", credit,
                    "net", debit.subtract(credit),
                    "lineCount", BigDecimal.valueOf(e.getValue().lineCount()[0])));
        }
        // Untagged last, tagged centres alphabetical.
        rows.sort(Comparator.comparing(r -> "(untagged)".equals(r.get("centre")) ? "￿" : (String) r.get("centre")));

        long taggedCentres = byCentre.keySet().stream().filter(k -> !"(untagged)".equals(k)).count();

        return response("cost-centres", "Cost Centres",
                "Journal activity grouped by cost centre — tag lines on manual journals to use this.",
                startDate, endDate, ctx.currency(),
                metrics(metric("centres", "Cost Centres", BigDecimal.valueOf(taggedCentres), "number"),
                        metric("tagged", "Tagged Amount (Dr+Cr)", taggedAmount, "currency")),
                columns(col("centre", "Cost Centre", "text"),
                        col("debit", "Debit", "currency"), col("credit", "Credit", "currency"),
                        col("net", "Net (Dr−Cr)", "currency"), col("lineCount", "Lines", "number")),
                rows);
    }

    /**
     * Interest on overdue receivables (Tally's "interest calculation"):
     * simple interest at {@code ar.interest_rate_pa} (default 18% p.a.) on
     * each overdue invoice's balance for the days past due. Read-only — use
     * it for negotiation/collections; raise a debit note manually if you
     * actually charge it.
     */
    public OperationalReportResponse overdueInterest() {
        Context ctx = context();
        LocalDate today = LocalDate.now();

        BigDecimal ratePa;
        try {
            ratePa = new BigDecimal(orgSettingsService.get(ctx.orgId(), "ar.interest_rate_pa", "18"));
        } catch (NumberFormatException e) {
            ratePa = new BigDecimal("18");
        }

        List<Invoice> overdue = invoiceRepository.findOverdueInvoices(ctx.orgId(), today);
        Map<UUID, String> names = contactNames(ctx.orgId(),
                overdue.stream().map(Invoice::getContactId).collect(Collectors.toSet()));

        BigDecimal totalInterest = BigDecimal.ZERO;
        BigDecimal totalOverdue = BigDecimal.ZERO;
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Invoice inv : overdue) {
            long days = java.time.temporal.ChronoUnit.DAYS.between(inv.getDueDate(), today);
            if (days <= 0) continue;
            BigDecimal balance = nz(inv.getBalanceDue());
            BigDecimal interest = balance.multiply(ratePa)
                    .multiply(BigDecimal.valueOf(days))
                    .divide(BigDecimal.valueOf(36500), 2, java.math.RoundingMode.HALF_UP);
            totalInterest = totalInterest.add(interest);
            totalOverdue = totalOverdue.add(balance);
            rows.add(row("customer", names.getOrDefault(inv.getContactId(), ""),
                    "invoiceNumber", inv.getInvoiceNumber(),
                    "dueDate", inv.getDueDate(),
                    "daysOverdue", BigDecimal.valueOf(days),
                    "balanceDue", balance,
                    "interest", interest));
        }
        rows.sort((a, b) -> ((BigDecimal) b.get("interest")).compareTo((BigDecimal) a.get("interest")));

        return response("overdue-interest", "Interest on Overdue",
                "Simple interest at " + ratePa.toPlainString() + "% p.a. on overdue invoice balances "
                        + "(set ar.interest_rate_pa in org settings).",
                today, today, ctx.currency(),
                metrics(metric("invoices", "Overdue Invoices", BigDecimal.valueOf(rows.size()), "number"),
                        metric("overdue", "Overdue Balance", totalOverdue, "currency"),
                        metric("interest", "Accrued Interest", totalInterest, "currency")),
                columns(col("customer", "Customer", "text"), col("invoiceNumber", "Invoice", "text"),
                        col("dueDate", "Due Date", "date"), col("daysOverdue", "Days Late", "number"),
                        col("balanceDue", "Balance Due", "currency"), col("interest", "Interest", "currency")),
                rows);
    }

    public OperationalReportResponse lowStockAlert() {
        Context ctx = context();
        List<Item> items = itemRepository.findByOrgIdAndIsDeletedFalseAndTrackInventoryTrue(ctx.orgId())
                .stream()
                .filter(Item::isActive)
                .filter(i -> nz(i.getReorderLevel()).compareTo(BigDecimal.ZERO) > 0)
                .toList();

        List<StockBalance> balances = stockBalanceRepository.findByOrgIdOrderByLastMovementAtDesc(ctx.orgId());
        Map<UUID, BigDecimal> totalOnHand = balances.stream()
                .collect(Collectors.groupingBy(StockBalance::getItemId,
                        Collectors.reducing(BigDecimal.ZERO, b -> nz(b.getQuantityOnHand()), BigDecimal::add)));

        LocalDate today = LocalDate.now();
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Item item : items) {
            BigDecimal onHand = totalOnHand.getOrDefault(item.getId(), BigDecimal.ZERO);
            BigDecimal reorderLevel = nz(item.getReorderLevel());
            if (onHand.compareTo(reorderLevel) <= 0) {
                BigDecimal deficit = reorderLevel.subtract(onHand);
                rows.add(row("sku", item.getSku(),
                        "item", item.getName(),
                        "onHand", onHand,
                        "reorderLevel", reorderLevel,
                        "deficit", deficit,
                        "reorderQty", nz(item.getReorderQuantity()),
                        "purchasePrice", nz(item.getPurchasePrice()),
                        "estCost", deficit.multiply(nz(item.getPurchasePrice()))));
            }
        }
        rows.sort((a, b) -> ((BigDecimal) b.get("deficit")).compareTo((BigDecimal) a.get("deficit")));

        BigDecimal totalEstCost = rows.stream()
                .map(r -> (BigDecimal) r.get("estCost"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return response("low-stock", "Low Stock Alert",
                "Items below reorder level, sorted by deficit.",
                today, today, ctx.currency(),
                metrics(metric("items", "Low Stock Items", BigDecimal.valueOf(rows.size()), "number"),
                        metric("estCost", "Est. Reorder Cost", totalEstCost, "currency")),
                columns(col("sku", "SKU", "text"), col("item", "Item", "text"),
                        col("onHand", "On Hand", "number"), col("reorderLevel", "Reorder Level", "number"),
                        col("deficit", "Deficit", "number"), col("reorderQty", "Reorder Qty", "number"),
                        col("purchasePrice", "Unit Price", "currency"), col("estCost", "Est. Cost", "currency")),
                rows);
    }

    public OperationalReportResponse gstSummary(LocalDate startDate, LocalDate endDate) {
        Context ctx = context();
        List<Invoice> invoices = invoiceRepository.findPostedByOrgAndDateRange(ctx.orgId(), startDate, endDate);

        BigDecimal outputTaxable = BigDecimal.ZERO;
        BigDecimal outputTax = BigDecimal.ZERO;

        for (Invoice inv : invoices) {
            outputTaxable = outputTaxable.add(nz(inv.getSubtotal()));
            outputTax = outputTax.add(nz(inv.getTaxAmount()));
        }

        List<PurchaseBill> bills = purchaseBillRepository.findPostedByOrgAndDateRange(
                ctx.orgId(), startDate, endDate);
        BigDecimal inputTaxable = BigDecimal.ZERO;
        BigDecimal inputTax = BigDecimal.ZERO;

        for (PurchaseBill bill : bills) {
            inputTaxable = inputTaxable.add(nz(bill.getSubtotal()));
            inputTax = inputTax.add(nz(bill.getTaxAmount()));
        }

        BigDecimal netPayable = outputTax.subtract(inputTax);

        List<Map<String, Object>> rows = List.of(
                row("category", "Output Tax (Sales)", "count", BigDecimal.valueOf(invoices.size()),
                        "taxable", outputTaxable, "tax", outputTax),
                row("category", "Input Credit (Purchases)", "count", BigDecimal.valueOf(bills.size()),
                        "taxable", inputTaxable, "tax", inputTax),
                row("category", "Net Payable", "count", BigDecimal.ZERO,
                        "taxable", outputTaxable.subtract(inputTaxable), "tax", netPayable)
        );

        return response("gst-summary", "GST Summary",
                "Output tax vs input credit summary for the period.",
                startDate, endDate, ctx.currency(),
                metrics(metric("output", "Output Tax", outputTax, "currency"),
                        metric("input", "Input Credit", inputTax, "currency"),
                        metric("net", "Net Payable", netPayable, "currency")),
                columns(col("category", "Category", "text"), col("count", "Transactions", "number"),
                        col("taxable", "Taxable Amount", "currency"), col("tax", "Tax Amount", "currency")),
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
