package com.katasticho.erp.fieldforce.service;

import com.katasticho.erp.ar.dto.CustomerReceiptRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.CustomerReceiptService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.dto.ContactLedgerResponse;
import com.katasticho.erp.contact.dto.ContactResponse;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.contact.service.ContactService;
import com.katasticho.erp.fieldsales.entity.FieldVisit;
import com.katasticho.erp.fieldsales.entity.RouteExecution;
import com.katasticho.erp.fieldsales.service.FieldSalesService;
import com.katasticho.erp.fieldsales.service.FieldTrackingService;
import com.katasticho.erp.sales.dto.CreateSalesOrderRequest;
import com.katasticho.erp.sales.dto.SalesOrderLineRequest;
import com.katasticho.erp.sales.dto.SalesOrderResponse;
import com.katasticho.erp.sales.service.SalesOrderService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Narrow mobile facade for the Katasticho Field app. Reuses existing ERP
 * services (field-sales, contacts, sales orders, payments, GPS tracking) and
 * shapes them into a small, offline-friendly surface — rather than exposing the
 * full ERP API to field users. Every call is scoped to the logged-in
 * salesperson via {@link TenantContext}.
 */
@Service
@RequiredArgsConstructor
public class FieldFacadeService {

    private final FieldSalesService fieldSalesService;
    private final FieldTrackingService fieldTrackingService;
    private final ContactService contactService;
    private final ContactLedgerService contactLedgerService;
    private final InvoiceRepository invoiceRepository;
    private final SalesOrderService salesOrderService;
    private final CustomerReceiptService customerReceiptService;

    // ── Today's route + visits ───────────────────────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> today() {
        LocalDate date = LocalDate.now();
        UUID me = TenantContext.getCurrentUserId();
        List<RouteExecution> executions = fieldSalesService.getExecutionsForSalesperson(me, date);

        Map<UUID, String> names = new HashMap<>();
        List<Map<String, Object>> execRows = new ArrayList<>();
        for (RouteExecution ex : executions) {
            List<Map<String, Object>> visitRows = new ArrayList<>();
            for (FieldVisit v : fieldSalesService.getVisits(ex.getId())) {
                visitRows.add(visitRow(v, names));
            }
            Map<String, Object> e = new LinkedHashMap<>();
            e.put("executionId", ex.getId());
            e.put("status", ex.getStatus());
            e.put("date", ex.getExecutionDate());
            e.put("visits", visitRows);
            execRows.add(e);
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("date", date);
        out.put("executions", execRows);
        out.put("visitCount", execRows.stream().mapToInt(e -> ((List<?>) e.get("visits")).size()).sum());
        return out;
    }

    // ── Dealers (parties) ────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<Map<String, Object>> dealers(String search) {
        return contactService.list("CUSTOMER", search, PageRequest.of(0, 200))
                .getContent().stream().map(this::dealerRow).toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> dealerDetail(UUID dealerId) {
        ContactResponse c = contactService.get(dealerId);
        ContactLedgerResponse ledger = contactLedgerService.getLedger(dealerId, null, null);

        List<Map<String, Object>> openInvoices = openInvoices(dealerId).stream()
                .map(this::invoiceRow).toList();

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("dealer", dealerRow(c));
        out.put("outstanding", ledger.closingBalance());
        out.put("totalInvoiced", ledger.totalInvoiced());
        out.put("totalPaid", ledger.totalPaid());
        out.put("openInvoices", openInvoices);
        return out;
    }

    // ── Visits: check-in / check-out ─────────────────────────────────────

    @Transactional
    public FieldVisit checkIn(UUID visitId, BigDecimal latitude, BigDecimal longitude) {
        return fieldSalesService.checkIn(visitId, latitude, longitude);
    }

    @Transactional
    public FieldVisit checkOut(UUID visitId, BigDecimal latitude, BigDecimal longitude, String notes) {
        return fieldSalesService.checkOut(visitId, latitude, longitude, notes);
    }

    // ── Order booking ────────────────────────────────────────────────────

    /** Books a sales order for a dealer (reuses SalesOrderService — credit/scheme/pricing apply). */
    @Transactional
    public Map<String, Object> createOrder(UUID dealerId, List<SalesOrderLineRequest> lines,
                                           String notes, UUID visitId) {
        if (lines == null || lines.isEmpty()) {
            throw new BusinessException("At least one line is required", "FIELD_ORDER_EMPTY",
                    HttpStatus.BAD_REQUEST);
        }
        CreateSalesOrderRequest req = new CreateSalesOrderRequest(
                dealerId, lines, LocalDate.now(), null, null,
                null, null, null, null, null, null, null, notes, null, null, null, Boolean.TRUE);
        SalesOrderResponse so = salesOrderService.create(req);

        // Stamp the visit if the order was booked during one.
        if (visitId != null) {
            fieldSalesService.recordVisitOrder(visitId, so.id(), so.totalAmount());
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("salesOrderId", so.id());
        out.put("status", so.status());
        out.put("totalAmount", so.totalAmount());
        if (so.warnings() != null && !so.warnings().isEmpty()) {
            out.put("warnings", so.warnings());
        }
        return out;
    }

    // ── Collections (FIFO across the dealer's open invoices) ─────────────

    @Transactional
    public Map<String, Object> recordCollection(UUID dealerId, BigDecimal amount,
                                                String paymentMethod, UUID visitId) {
        if (amount == null || amount.signum() <= 0) {
            throw new BusinessException("Collection amount must be positive",
                    "FIELD_COLLECTION_INVALID", HttpStatus.BAD_REQUEST);
        }
        String method = paymentMethod != null && !paymentMethod.isBlank()
                ? paymentMethod.trim().toUpperCase(Locale.ROOT) : "CASH";
        if (!Set.of("CASH", "UPI", "BANK_TRANSFER", "CHEQUE", "CARD").contains(method)) {
            throw new BusinessException("Unsupported collection payment method: " + method,
                    "FIELD_COLLECTION_PAYMENT_METHOD_INVALID", HttpStatus.BAD_REQUEST);
        }

        BigDecimal remaining = amount;
        List<CustomerReceiptRequest.AllocationRequest> allocations = new ArrayList<>();
        for (Invoice invoice : openInvoices(dealerId)) {
            if (remaining.signum() <= 0) break;
            BigDecimal applied = nz(invoice.getBalanceDue()).min(remaining);
            if (applied.signum() > 0) {
                allocations.add(new CustomerReceiptRequest.AllocationRequest(
                        invoice.getId(), applied));
                remaining = remaining.subtract(applied);
            }
        }

        var receipt = customerReceiptService.recordReceipt(new CustomerReceiptRequest(
                dealerId, amount, method, LocalDate.now(), null,
                "Field collection", null, allocations));
        BigDecimal allocated = amount.subtract(remaining);
        if (visitId != null) {
            fieldSalesService.recordVisitCollection(visitId, amount, method);
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("requested", amount);
        out.put("allocated", allocated);
        out.put("unallocated", remaining);
        out.put("advanceAmount", receipt.advanceAmount());
        out.put("receipt", receipt);
        return out;
    }

    // -- GPS pings ────────────────────────────────────────────────────────

    @Transactional
    public int recordPings(List<FieldTrackingService.PingRequest> pings) {
        if (pings == null || pings.isEmpty()) return 0;
        return fieldTrackingService.recordPings(pings).size();
    }

    // ── Sync bootstrap ───────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> bootstrap() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("serverTime", java.time.Instant.now());
        out.put("today", today());
        out.put("dealers", dealers(null));
        return out;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private List<Invoice> openInvoices(UUID dealerId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return invoiceRepository
                .findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                        orgId, dealerId, PageRequest.of(0, 500))
                .getContent().stream()
                .filter(i -> nz(i.getBalanceDue()).signum() > 0)
                .sorted(Comparator.comparing(Invoice::getInvoiceDate)) // oldest first
                .toList();
    }

    private Map<String, Object> visitRow(FieldVisit v, Map<UUID, String> nameCache) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("visitId", v.getId());
        m.put("dealerId", v.getContactId());
        m.put("dealerName", dealerName(v.getContactId(), nameCache));
        m.put("sequence", v.getSequenceNumber());
        m.put("status", v.getStatus());
        m.put("checkInTime", v.getCheckInTime());
        m.put("checkOutTime", v.getCheckOutTime());
        m.put("orderValue", nz(v.getOrderValue()));
        m.put("collectionAmount", nz(v.getCollectionAmount()));
        return m;
    }

    private String dealerName(UUID contactId, Map<UUID, String> cache) {
        if (contactId == null) return null;
        return cache.computeIfAbsent(contactId, id -> {
            try {
                return contactService.get(id).displayName();
            } catch (Exception e) {
                return null;
            }
        });
    }

    private Map<String, Object> dealerRow(ContactResponse c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.id());
        m.put("name", c.displayName());
        m.put("city", c.billingCity());
        m.put("phone", c.mobile() != null ? c.mobile() : c.phone());
        m.put("gstin", c.gstin());
        return m;
    }

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

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
