package com.katasticho.erp.automation;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
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

import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class PaymentReminderJob {

    private final OrganisationRepository orgRepository;
    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final AppUserRepository userRepository;
    private final NotificationService notificationService;

    @Scheduled(cron = "${app.automation.payment-reminder.cron:0 0 9 * * *}")
    @Transactional
    public void run() {
        LocalDate today = LocalDate.now();
        List<LocalDate> dates = List.of(
                today,
                today.minusDays(3),
                today.minusDays(7),
                today.minusDays(15),
                today.minusDays(30)
        );

        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndIsActiveTrue();
        int total = 0;
        int orgCount = 0;

        for (Organisation org : orgs) {
            List<Invoice> invoices = invoiceRepository.findDueOnDates(org.getId(), dates);
            if (invoices.isEmpty()) continue;

            AppUser admin = userRepository.findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER")
                    .orElse(null);
            if (admin == null) continue;

            orgCount++;
            for (Invoice inv : invoices) {
                if (notificationService.existsTodayForEntity(org.getId(), "PAYMENT_REMINDER", inv.getId())) {
                    continue;
                }

                long daysOverdue = ChronoUnit.DAYS.between(inv.getDueDate(), today);
                String daysLabel = daysOverdue == 0 ? "Due today" : daysOverdue + " days overdue";
                BigDecimal balance = inv.getBalanceDue();

                String customerName = "Customer";
                String customerPhone = null;
                Contact contact = contactRepository.findById(inv.getContactId()).orElse(null);
                if (contact != null) {
                    customerName = contact.getDisplayName();
                    customerPhone = contact.getPhone() != null ? contact.getPhone() : contact.getMobile();
                }

                String title = "Payment reminder: " + inv.getInvoiceNumber();
                String message = String.format("₹%s due from %s. %s.",
                        balance.toPlainString(), customerName, daysLabel);

                Map<String, Object> metadata = new HashMap<>();
                metadata.put("invoiceNumber", inv.getInvoiceNumber());
                metadata.put("balanceDue", balance);
                metadata.put("customerName", customerName);
                metadata.put("daysOverdue", daysOverdue);

                if (customerPhone != null && !customerPhone.isBlank()) {
                    String phone = customerPhone.replaceAll("[^0-9+]", "");
                    if (!phone.startsWith("+")) phone = "+91" + phone;
                    String whatsappText = String.format(
                            "Hi %s, friendly reminder that ₹%s is due for invoice %s. " +
                            "Please pay at your earliest convenience. — %s",
                            customerName, balance.toPlainString(),
                            inv.getInvoiceNumber(), org.getName());
                    String whatsappLink = "https://wa.me/" + phone.replace("+", "")
                            + "?text=" + URLEncoder.encode(whatsappText, StandardCharsets.UTF_8);
                    metadata.put("whatsappLink", whatsappLink);
                }

                String severity = daysOverdue >= 15 ? "CRITICAL" : daysOverdue >= 3 ? "WARNING" : "INFO";
                notificationService.send(org.getId(), admin.getId(), title, message,
                        severity, "PAYMENT_REMINDER", "INVOICE", inv.getId(), metadata);
                total++;
            }
        }

        if (total > 0) {
            log.info("Payment reminders sent: {} for {} orgs", total, orgCount);
        }
    }
}
