package com.katasticho.erp.automation;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.service.NotificationService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Enhances the existing PurchaseBillService.markOverdueBills scheduler
 * by adding notification creation. This job runs at the same time (1 AM)
 * but only sends notifications — the status update is handled by the
 * existing scheduler in PurchaseBillService.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class OverdueBillJob {

    private final OrganisationRepository orgRepository;
    private final PurchaseBillRepository billRepository;
    private final ContactRepository contactRepository;
    private final AppUserRepository userRepository;
    private final NotificationService notificationService;

    @Scheduled(cron = "${app.automation.overdue-bill.cron:0 5 1 * * *}")
    @Transactional(readOnly = true)
    public void run() {
        LocalDate today = LocalDate.now();
        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndActiveTrue();
        int count = 0;
        int orgCount = 0;

        for (Organisation org : orgs) {
            List<PurchaseBill> overdue = billRepository.findOverdueBills(org.getId(), today);
            if (overdue.isEmpty()) continue;

            AppUser admin = userRepository.findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER")
                    .orElse(null);
            if (admin == null) continue;

            for (PurchaseBill bill : overdue) {
                if (notificationService.existsTodayForEntity(org.getId(), "BILL_OVERDUE", bill.getId())) {
                    continue;
                }

                String vendorName = "Vendor";
                Contact vendor = contactRepository.findById(bill.getContactId()).orElse(null);
                if (vendor != null) {
                    vendorName = vendor.getDisplayName();
                }

                String title = "Bill overdue: " + vendorName;
                String message = String.format("₹%s overdue to %s. Bill %s was due on %s.",
                        bill.getBalanceDue().toPlainString(), vendorName,
                        bill.getBillNumber(), bill.getDueDate());

                Map<String, Object> metadata = new HashMap<>();
                metadata.put("billNumber", bill.getBillNumber());
                metadata.put("vendorName", vendorName);
                metadata.put("balanceDue", bill.getBalanceDue());
                metadata.put("dueDate", bill.getDueDate().toString());

                notificationService.send(org.getId(), admin.getId(), title, message,
                        "WARNING", "BILL_OVERDUE", "BILL", bill.getId(), metadata);
                count++;
            }

            if (count > 0) orgCount++;
        }

        if (count > 0) {
            log.info("Overdue bills notified: {} across {} orgs", count, orgCount);
        }
    }
}
