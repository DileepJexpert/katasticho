package com.katasticho.erp.ap.service;

import com.katasticho.erp.ap.dto.ApAgeingReportResponse;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ApReportService {

    private final PurchaseBillRepository purchaseBillRepository;
    private final ContactRepository contactRepository;

    public ApAgeingReportResponse getAgeingReport(LocalDate asOfDate) {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<PurchaseBill> outstanding = purchaseBillRepository.findOutstandingBills(orgId);

        Map<UUID, List<PurchaseBill>> byVendor = outstanding.stream()
                .collect(Collectors.groupingBy(PurchaseBill::getContactId,
                        LinkedHashMap::new, Collectors.toList()));

        BigDecimal totalCurrent = BigDecimal.ZERO;
        BigDecimal total1to30 = BigDecimal.ZERO;
        BigDecimal total31to60 = BigDecimal.ZERO;
        BigDecimal total61to90 = BigDecimal.ZERO;
        BigDecimal total90plus = BigDecimal.ZERO;
        BigDecimal grandTotal = BigDecimal.ZERO;

        List<ApAgeingReportResponse.VendorAgeing> vendorAgeings = new ArrayList<>();

        for (Map.Entry<UUID, List<PurchaseBill>> entry : byVendor.entrySet()) {
            Contact contact = contactRepository.findById(entry.getKey()).orElse(null);
            if (contact == null) continue;

            BigDecimal vCurrent = BigDecimal.ZERO;
            BigDecimal v1to30 = BigDecimal.ZERO;
            BigDecimal v31to60 = BigDecimal.ZERO;
            BigDecimal v61to90 = BigDecimal.ZERO;
            BigDecimal v90plus = BigDecimal.ZERO;
            BigDecimal vTotal = BigDecimal.ZERO;

            List<ApAgeingReportResponse.BillAgeing> billAgeings = new ArrayList<>();

            for (PurchaseBill bill : entry.getValue()) {
                long daysOverdue = bill.getDueDate() != null
                        ? ChronoUnit.DAYS.between(bill.getDueDate(), asOfDate)
                        : 0;
                BigDecimal balance = bill.getBalanceDue();
                String bucket;

                if (daysOverdue <= 0) {
                    bucket = "CURRENT";
                    vCurrent = vCurrent.add(balance);
                } else if (daysOverdue <= 30) {
                    bucket = "1-30";
                    v1to30 = v1to30.add(balance);
                } else if (daysOverdue <= 60) {
                    bucket = "31-60";
                    v31to60 = v31to60.add(balance);
                } else if (daysOverdue <= 90) {
                    bucket = "61-90";
                    v61to90 = v61to90.add(balance);
                } else {
                    bucket = "90+";
                    v90plus = v90plus.add(balance);
                }

                vTotal = vTotal.add(balance);
                billAgeings.add(new ApAgeingReportResponse.BillAgeing(
                        bill.getId(), bill.getBillNumber(), balance,
                        Math.max(0, daysOverdue), bucket));
            }

            vendorAgeings.add(new ApAgeingReportResponse.VendorAgeing(
                    contact.getId(), contact.getDisplayName(), vTotal,
                    vCurrent, v1to30, v31to60, v61to90, v90plus, billAgeings));

            totalCurrent = totalCurrent.add(vCurrent);
            total1to30 = total1to30.add(v1to30);
            total31to60 = total31to60.add(v31to60);
            total61to90 = total61to90.add(v61to90);
            total90plus = total90plus.add(v90plus);
            grandTotal = grandTotal.add(vTotal);
        }

        return new ApAgeingReportResponse(
                grandTotal, totalCurrent, total1to30, total31to60,
                total61to90, total90plus, vendorAgeings);
    }
}
