package com.katasticho.erp.reporting.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.VendorPaymentAllocation;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentAllocationRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * MSME Form 1 annexure (MCA half-yearly return under MSMED Act §9 read with
 * the 22 Jan 2019 order): supplier-wise dues to MSME-registered vendors,
 * split at the statutory 45-day limit (§15 — agreed credit period, capped at
 * 45 days from acceptance).
 *
 * <p>Deadline per bill = {@code min(dueDate, billDate + 45d)} — an agreed
 * period shorter than 45 days binds, a longer one is capped by the Act. The
 * bill date stands in for the day of acceptance (we don't capture a separate
 * acceptance date).
 *
 * <p>Vendors are the contacts flagged {@code msmeRegistered} (VENDOR/BOTH).
 * PAN and Udyam number come straight off the contact master — the annexure
 * is only as complete as the vendor master, so blank PANs surface as blank
 * columns rather than being silently dropped.
 */
@Service
@RequiredArgsConstructor
public class MsmeForm1Service {

    private static final int MSME_LIMIT_DAYS = 45;

    private final ContactRepository contactRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final VendorPaymentAllocationRepository allocationRepository;
    private final Clock clock;

    @Transactional(readOnly = true)
    public Map<String, Object> report(LocalDate asOf, LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate effectiveAsOf = asOf != null ? asOf : LocalDate.now(clock);
        LocalDate[] halfYear = halfYearOf(effectiveAsOf);
        LocalDate effectiveFrom = from != null ? from : halfYear[0];
        LocalDate effectiveTo = to != null ? to : halfYear[1];

        List<Contact> vendors = contactRepository
                .findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse(orgId).stream()
                .filter(c -> c.getContactType() == ContactType.VENDOR
                        || c.getContactType() == ContactType.BOTH)
                .toList();

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("asOf", effectiveAsOf);
        payload.put("periodFrom", effectiveFrom);
        payload.put("periodTo", effectiveTo);
        payload.put("msmeVendorCount", vendors.size());

        if (vendors.isEmpty()) {
            payload.put("outstandingRows", List.of());
            payload.put("paidRows", List.of());
            payload.put("supplierSummary", List.of());
            payload.put("totals", totals(List.of(), List.of()));
            payload.put("note", "No vendors are flagged MSME-registered on the contact master.");
            return payload;
        }

        Map<UUID, Contact> vendorById = vendors.stream()
                .collect(Collectors.toMap(Contact::getId, Function.identity()));
        List<PurchaseBill> bills = purchaseBillRepository
                .findByOrgIdAndContactIdInAndIsDeletedFalse(orgId, vendorById.keySet()).stream()
                .filter(b -> !"DRAFT".equals(b.getStatus()) && !"VOID".equals(b.getStatus()))
                .filter(b -> b.getBillDate() != null && !b.getBillDate().isAfter(effectiveAsOf))
                .toList();
        Map<UUID, PurchaseBill> billById = bills.stream()
                .collect(Collectors.toMap(PurchaseBill::getId, Function.identity()));

        List<Map<String, Object>> outstandingRows = new ArrayList<>();
        for (PurchaseBill bill : bills) {
            BigDecimal due = bill.getBalanceDue();
            if (due == null || due.compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }
            LocalDate deadline = msmeDeadline(bill);
            long daysOverdue = Math.max(0, ChronoUnit.DAYS.between(deadline, effectiveAsOf));
            outstandingRows.add(row(vendorById.get(bill.getContactId()), bill, deadline, due,
                    daysOverdue, null, null));
        }
        outstandingRows.sort(Comparator.comparingLong(
                r -> -((Long) r.get("daysOverdue"))));

        List<Map<String, Object>> paidRows = new ArrayList<>();
        if (!bills.isEmpty()) {
            for (VendorPaymentAllocation allocation :
                    allocationRepository.findByPurchaseBillIdIn(billById.keySet())) {
                var payment = allocation.getVendorPayment();
                if (payment == null || payment.isDeleted() || payment.getPaymentDate() == null) {
                    continue;
                }
                LocalDate paymentDate = payment.getPaymentDate();
                if (paymentDate.isBefore(effectiveFrom) || paymentDate.isAfter(effectiveTo)) {
                    continue;
                }
                PurchaseBill bill = billById.get(allocation.getPurchaseBillId());
                LocalDate deadline = msmeDeadline(bill);
                long daysLate = Math.max(0, ChronoUnit.DAYS.between(deadline, paymentDate));
                paidRows.add(row(vendorById.get(bill.getContactId()), bill, deadline,
                        allocation.getAmountApplied(), daysLate, paymentDate,
                        payment.getPaymentNumber()));
            }
        }
        paidRows.sort(Comparator.comparingLong(r -> -((Long) r.get("daysOverdue"))));

        payload.put("outstandingRows", outstandingRows);
        payload.put("paidRows", paidRows);
        payload.put("supplierSummary", supplierSummary(vendorById, outstandingRows, paidRows));
        payload.put("totals", totals(outstandingRows, paidRows));
        return payload;
    }

    /** MCA-style CSV: one file, Section column separates the annexure parts. */
    @Transactional(readOnly = true)
    public byte[] exportCsv(LocalDate asOf, LocalDate from, LocalDate to) {
        Map<String, Object> report = report(asOf, from, to);
        StringBuilder csv = new StringBuilder();
        csv.append("Section,Supplier,PAN,MSME Reg No,Bill No,Vendor Bill No,Bill Date,")
                .append("MSME Deadline (45d),Amount,Days Beyond 45,Payment Date,Payment No\n");
        appendRows(csv, castRows(report.get("outstandingRows")), true);
        appendRows(csv, castRows(report.get("paidRows")), false);
        return csv.toString().getBytes(StandardCharsets.UTF_8);
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> castRows(Object rows) {
        return rows instanceof List<?> list ? (List<Map<String, Object>>) list : List.of();
    }

    private static void appendRows(StringBuilder csv, List<Map<String, Object>> rows,
                                   boolean outstanding) {
        for (Map<String, Object> row : rows) {
            long beyond = (Long) row.get("daysOverdue");
            String section = outstanding
                    ? (beyond > 0 ? "OUTSTANDING_OVER_45" : "OUTSTANDING_WITHIN_45")
                    : (beyond > 0 ? "PAID_BEYOND_45" : "PAID_WITHIN_45");
            csv.append(section).append(',')
                    .append(csv(row.get("supplier"))).append(',')
                    .append(csv(row.get("pan"))).append(',')
                    .append(csv(row.get("msmeRegistrationNo"))).append(',')
                    .append(csv(row.get("billNumber"))).append(',')
                    .append(csv(row.get("vendorBillNumber"))).append(',')
                    .append(csv(row.get("billDate"))).append(',')
                    .append(csv(row.get("msmeDeadline"))).append(',')
                    .append(csv(row.get("amount"))).append(',')
                    .append(beyond).append(',')
                    .append(csv(row.get("paymentDate"))).append(',')
                    .append(csv(row.get("paymentNumber"))).append('\n');
        }
    }

    private Map<String, Object> row(Contact vendor, PurchaseBill bill, LocalDate deadline,
                                    BigDecimal amount, long daysBeyond, LocalDate paymentDate,
                                    String paymentNumber) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("contactId", vendor != null ? vendor.getId() : null);
        row.put("supplier", vendor != null ? vendor.getDisplayName() : null);
        row.put("pan", vendor != null ? vendor.getPan() : null);
        row.put("msmeRegistrationNo", vendor != null ? vendor.getMsmeRegistrationNo() : null);
        row.put("billId", bill.getId());
        row.put("billNumber", bill.getBillNumber());
        row.put("vendorBillNumber", bill.getVendorBillNumber());
        row.put("billDate", bill.getBillDate());
        row.put("msmeDeadline", deadline);
        row.put("amount", amount);
        row.put("daysOverdue", daysBeyond);
        row.put("beyond45", daysBeyond > 0);
        row.put("paymentDate", paymentDate);
        row.put("paymentNumber", paymentNumber);
        return row;
    }

    private List<Map<String, Object>> supplierSummary(Map<UUID, Contact> vendorById,
                                                      List<Map<String, Object>> outstandingRows,
                                                      List<Map<String, Object>> paidRows) {
        Map<UUID, Map<String, Object>> byVendor = new LinkedHashMap<>();
        for (Contact vendor : vendorById.values()) {
            Map<String, Object> summary = new LinkedHashMap<>();
            summary.put("contactId", vendor.getId());
            summary.put("supplier", vendor.getDisplayName());
            summary.put("pan", vendor.getPan());
            summary.put("msmeRegistrationNo", vendor.getMsmeRegistrationNo());
            summary.put("outstandingWithin45", BigDecimal.ZERO);
            summary.put("outstandingOver45", BigDecimal.ZERO);
            summary.put("paidWithin45", BigDecimal.ZERO);
            summary.put("paidBeyond45", BigDecimal.ZERO);
            byVendor.put(vendor.getId(), summary);
        }
        accumulate(byVendor, outstandingRows, "outstandingWithin45", "outstandingOver45");
        accumulate(byVendor, paidRows, "paidWithin45", "paidBeyond45");
        return byVendor.values().stream()
                .sorted(Comparator.comparing(
                        s -> ((BigDecimal) s.get("outstandingOver45")).negate()))
                .toList();
    }

    private static void accumulate(Map<UUID, Map<String, Object>> byVendor,
                                   List<Map<String, Object>> rows,
                                   String withinKey, String beyondKey) {
        for (Map<String, Object> row : rows) {
            Map<String, Object> summary = byVendor.get((UUID) row.get("contactId"));
            if (summary == null) {
                continue;
            }
            String key = (Long) row.get("daysOverdue") > 0 ? beyondKey : withinKey;
            summary.put(key, ((BigDecimal) summary.get(key)).add((BigDecimal) row.get("amount")));
        }
    }

    private static Map<String, Object> totals(List<Map<String, Object>> outstandingRows,
                                              List<Map<String, Object>> paidRows) {
        Map<String, Object> totals = new LinkedHashMap<>();
        totals.put("outstandingOver45", sum(outstandingRows, true));
        totals.put("outstandingWithin45", sum(outstandingRows, false));
        totals.put("paidBeyond45", sum(paidRows, true));
        totals.put("paidWithin45", sum(paidRows, false));
        return totals;
    }

    private static BigDecimal sum(List<Map<String, Object>> rows, boolean beyond45) {
        return rows.stream()
                .filter(r -> ((Long) r.get("daysOverdue") > 0) == beyond45)
                .map(r -> (BigDecimal) r.get("amount"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /** Agreed period binds when shorter; the Act caps anything longer at 45 days. */
    static LocalDate msmeDeadline(PurchaseBill bill) {
        LocalDate cap = bill.getBillDate().plusDays(MSME_LIMIT_DAYS);
        LocalDate dueDate = bill.getDueDate();
        return (dueDate != null && dueDate.isBefore(cap)) ? dueDate : cap;
    }

    /** MCA half-year buckets: Apr–Sep and Oct–Mar. */
    static LocalDate[] halfYearOf(LocalDate date) {
        int month = date.getMonthValue();
        if (month >= 4 && month <= 9) {
            return new LocalDate[]{LocalDate.of(date.getYear(), 4, 1),
                    LocalDate.of(date.getYear(), 9, 30)};
        }
        int startYear = month >= 10 ? date.getYear() : date.getYear() - 1;
        return new LocalDate[]{LocalDate.of(startYear, 10, 1),
                LocalDate.of(startYear + 1, 3, 31)};
    }

    private static String csv(Object value) {
        if (value == null) {
            return "";
        }
        String s = value.toString();
        if (s.contains(",") || s.contains("\"") || s.contains("\n")) {
            return '"' + s.replace("\"", "\"\"") + '"';
        }
        return s;
    }
}
