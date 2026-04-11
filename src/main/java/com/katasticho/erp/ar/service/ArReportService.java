package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.AgeingReportResponse;
import com.katasticho.erp.ar.entity.Customer;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.CustomerRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ArReportService {

    private final InvoiceRepository invoiceRepository;
    private final CustomerRepository customerRepository;
    private final TaxLineItemRepository taxLineItemRepository;

    /**
     * AR Ageing Report — buckets: Current, 1-30, 31-60, 61-90, 90+ days.
     * Groups by customer with invoice-level detail.
     */
    public AgeingReportResponse getAgeingReport(LocalDate asOfDate) {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<Invoice> outstanding = invoiceRepository.findOutstandingInvoices(orgId);

        // Group by customer
        Map<UUID, List<Invoice>> byCustomer = outstanding.stream()
                .collect(Collectors.groupingBy(Invoice::getCustomerId, LinkedHashMap::new, Collectors.toList()));

        BigDecimal totalCurrent = BigDecimal.ZERO;
        BigDecimal total1to30 = BigDecimal.ZERO;
        BigDecimal total31to60 = BigDecimal.ZERO;
        BigDecimal total61to90 = BigDecimal.ZERO;
        BigDecimal total90plus = BigDecimal.ZERO;
        BigDecimal grandTotal = BigDecimal.ZERO;

        List<AgeingReportResponse.CustomerAgeing> customerAgeings = new ArrayList<>();

        for (Map.Entry<UUID, List<Invoice>> entry : byCustomer.entrySet()) {
            Customer customer = customerRepository.findById(entry.getKey()).orElse(null);
            if (customer == null) continue;

            BigDecimal custCurrent = BigDecimal.ZERO;
            BigDecimal cust1to30 = BigDecimal.ZERO;
            BigDecimal cust31to60 = BigDecimal.ZERO;
            BigDecimal cust61to90 = BigDecimal.ZERO;
            BigDecimal cust90plus = BigDecimal.ZERO;
            BigDecimal custTotal = BigDecimal.ZERO;

            List<AgeingReportResponse.InvoiceAgeing> invoiceAgeings = new ArrayList<>();

            for (Invoice inv : entry.getValue()) {
                long daysOverdue = ChronoUnit.DAYS.between(inv.getDueDate(), asOfDate);
                BigDecimal balance = inv.getBalanceDue();
                String bucket;

                if (daysOverdue <= 0) {
                    bucket = "CURRENT";
                    custCurrent = custCurrent.add(balance);
                } else if (daysOverdue <= 30) {
                    bucket = "1-30";
                    cust1to30 = cust1to30.add(balance);
                } else if (daysOverdue <= 60) {
                    bucket = "31-60";
                    cust31to60 = cust31to60.add(balance);
                } else if (daysOverdue <= 90) {
                    bucket = "61-90";
                    cust61to90 = cust61to90.add(balance);
                } else {
                    bucket = "90+";
                    cust90plus = cust90plus.add(balance);
                }

                custTotal = custTotal.add(balance);

                invoiceAgeings.add(new AgeingReportResponse.InvoiceAgeing(
                        inv.getId(), inv.getInvoiceNumber(), balance,
                        Math.max(0, daysOverdue), bucket));
            }

            customerAgeings.add(new AgeingReportResponse.CustomerAgeing(
                    customer.getId(), customer.getName(), custTotal,
                    custCurrent, cust1to30, cust31to60, cust61to90, cust90plus,
                    invoiceAgeings));

            totalCurrent = totalCurrent.add(custCurrent);
            total1to30 = total1to30.add(cust1to30);
            total31to60 = total31to60.add(cust31to60);
            total61to90 = total61to90.add(cust61to90);
            total90plus = total90plus.add(cust90plus);
            grandTotal = grandTotal.add(custTotal);
        }

        return new AgeingReportResponse(
                grandTotal, totalCurrent, total1to30, total31to60,
                total61to90, total90plus, customerAgeings);
    }

    /**
     * Generate GSTR-1 JSON data for a given period.
     * Returns a Map suitable for JSON serialization in the GST portal format.
     */
    public Map<String, Object> generateGstr1(int year, int month) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Get all INVOICE tax line items for the period
        List<TaxLineItem> taxLines = taxLineItemRepository
                .findByOrgAndSourceTypeAndRegime(orgId, "INVOICE", "INDIA_GST");

        // Get invoices for the period
        List<Invoice> allInvoices = invoiceRepository
                .findByOrgIdAndIsDeletedFalseOrderByInvoiceDateDesc(orgId, Pageable.unpaged()).getContent();

        List<Invoice> periodInvoices = allInvoices.stream()
                .filter(inv -> inv.getPeriodYear() != null && inv.getPeriodYear() == computeFiscalYear(inv.getInvoiceDate(), 4)
                        && inv.getInvoiceDate().getMonthValue() == month
                        && inv.getInvoiceDate().getYear() == year)
                .filter(inv -> !"DRAFT".equals(inv.getStatus()) && !"CANCELLED".equals(inv.getStatus()))
                .toList();

        // Build B2B section (business-to-business, registered customers)
        List<Map<String, Object>> b2bRecords = new ArrayList<>();
        for (Invoice inv : periodInvoices) {
            Customer customer = customerRepository.findById(inv.getCustomerId()).orElse(null);
            if (customer == null || customer.getGstin() == null || customer.getGstin().isBlank()) continue;

            List<TaxLineItem> invTaxLines = taxLines.stream()
                    .filter(tl -> tl.getSourceId().equals(inv.getId()))
                    .toList();

            // Group tax lines by rate
            Map<BigDecimal, List<TaxLineItem>> byRate = invTaxLines.stream()
                    .collect(Collectors.groupingBy(TaxLineItem::getRate));

            List<Map<String, Object>> items = new ArrayList<>();
            for (Map.Entry<BigDecimal, List<TaxLineItem>> rateEntry : byRate.entrySet()) {
                BigDecimal taxableSum = rateEntry.getValue().stream()
                        .map(TaxLineItem::getTaxableAmount)
                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                BigDecimal taxSum = rateEntry.getValue().stream()
                        .map(TaxLineItem::getTaxAmount)
                        .reduce(BigDecimal.ZERO, BigDecimal::add);

                // Determine CGST/SGST vs IGST
                BigDecimal cgst = BigDecimal.ZERO, sgst = BigDecimal.ZERO, igst = BigDecimal.ZERO;
                for (TaxLineItem tl : rateEntry.getValue()) {
                    switch (tl.getComponentCode()) {
                        case "CGST" -> cgst = cgst.add(tl.getTaxAmount());
                        case "SGST" -> sgst = sgst.add(tl.getTaxAmount());
                        case "IGST" -> igst = igst.add(tl.getTaxAmount());
                    }
                }

                items.add(Map.of(
                        "rt", rateEntry.getKey(),
                        "txval", taxableSum,
                        "camt", cgst,
                        "samt", sgst,
                        "iamt", igst
                ));
            }

            b2bRecords.add(Map.of(
                    "ctin", customer.getGstin(),
                    "inv", List.of(Map.of(
                            "inum", inv.getInvoiceNumber(),
                            "idt", inv.getInvoiceDate().toString(),
                            "val", inv.getTotalAmount(),
                            "pos", inv.getPlaceOfSupply() != null ? inv.getPlaceOfSupply() : "",
                            "rchrg", inv.isReverseCharge() ? "Y" : "N",
                            "itms", items
                    ))
            ));
        }

        Map<String, Object> gstr1 = new LinkedHashMap<>();
        gstr1.put("gstin", ""); // Org's GSTIN — filled by caller
        gstr1.put("fp", String.format("%02d%d", month, year));
        gstr1.put("b2b", b2bRecords);

        return gstr1;
    }

    private int computeFiscalYear(LocalDate date, int fiscalYearStartMonth) {
        if (date.getMonthValue() >= fiscalYearStartMonth) {
            return date.getYear();
        }
        return date.getYear() - 1;
    }
}
