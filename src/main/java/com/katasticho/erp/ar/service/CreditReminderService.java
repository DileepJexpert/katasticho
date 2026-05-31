package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.CustomerRiskResponse;
import com.katasticho.erp.ar.dto.OverdueCustomerResponse;
import com.katasticho.erp.ar.dto.ReminderTextResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.ReminderLog;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.ReminderLogRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CreditReminderService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM yyyy");

    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final ReminderLogRepository reminderLogRepository;
    private final OrganisationRepository organisationRepository;
    private final OrgSettingsService orgSettingsService;

    public List<OverdueCustomerResponse> getOverdueCustomers() {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();

        List<Invoice> overdueInvoices = invoiceRepository.findOverdueInvoices(orgId, today);
        if (overdueInvoices.isEmpty()) return List.of();

        // Group by contact
        Map<UUID, List<Invoice>> byContact = overdueInvoices.stream()
                .collect(Collectors.groupingBy(Invoice::getContactId, LinkedHashMap::new, Collectors.toList()));

        // Fetch last reminder timestamps
        List<UUID> contactIds = new ArrayList<>(byContact.keySet());
        Map<UUID, Instant> lastReminders = reminderLogRepository
                .findLastRemindersByContacts(orgId, contactIds).stream()
                .collect(Collectors.toMap(
                        ReminderLogRepository.ContactLastReminder::getContactId,
                        ReminderLogRepository.ContactLastReminder::getLastSentAt));

        List<OverdueCustomerResponse> results = new ArrayList<>();

        for (Map.Entry<UUID, List<Invoice>> entry : byContact.entrySet()) {
            Contact contact = contactRepository.findById(entry.getKey()).orElse(null);
            if (contact == null) continue;

            List<Invoice> invoices = entry.getValue();
            BigDecimal totalOutstanding = BigDecimal.ZERO;
            BigDecimal overdueAmount = BigDecimal.ZERO;
            LocalDate oldestDueDate = null;
            long maxDaysOverdue = 0;

            List<OverdueCustomerResponse.OverdueInvoice> invoiceList = new ArrayList<>();

            for (Invoice inv : invoices) {
                BigDecimal balance = inv.getBalanceDue() != null ? inv.getBalanceDue() : inv.getTotalAmount();
                totalOutstanding = totalOutstanding.add(balance);
                long daysOverdue = ChronoUnit.DAYS.between(inv.getDueDate(), today);
                if (daysOverdue > 0) {
                    overdueAmount = overdueAmount.add(balance);
                }
                if (daysOverdue > maxDaysOverdue) maxDaysOverdue = daysOverdue;
                if (oldestDueDate == null || inv.getDueDate().isBefore(oldestDueDate)) {
                    oldestDueDate = inv.getDueDate();
                }

                invoiceList.add(new OverdueCustomerResponse.OverdueInvoice(
                        inv.getId(),
                        inv.getInvoiceNumber(),
                        inv.getTotalAmount(),
                        balance,
                        inv.getDueDate(),
                        Math.max(0, daysOverdue)
                ));
            }

            String phone = contact.getMobile() != null && !contact.getMobile().isBlank()
                    ? contact.getMobile() : contact.getPhone();

            results.add(new OverdueCustomerResponse(
                    contact.getId(),
                    contact.getDisplayName(),
                    phone,
                    totalOutstanding,
                    overdueAmount,
                    oldestDueDate,
                    maxDaysOverdue,
                    invoices.size(),
                    lastReminders.get(contact.getId()),
                    invoiceList
            ));
        }

        // Sort by total outstanding descending
        results.sort((a, b) -> b.totalOutstanding().compareTo(a.totalOutstanding()));
        return results;
    }

    public OverdueCustomerResponse getCustomerOutstanding(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));

        List<Invoice> invoices = invoiceRepository.findOutstandingByContact(orgId, contactId);

        BigDecimal totalOutstanding = BigDecimal.ZERO;
        BigDecimal overdueAmount = BigDecimal.ZERO;
        LocalDate oldestDueDate = null;
        long maxDaysOverdue = 0;

        List<OverdueCustomerResponse.OverdueInvoice> invoiceList = new ArrayList<>();

        for (Invoice inv : invoices) {
            BigDecimal balance = inv.getBalanceDue() != null ? inv.getBalanceDue() : inv.getTotalAmount();
            totalOutstanding = totalOutstanding.add(balance);
            long daysOverdue = ChronoUnit.DAYS.between(inv.getDueDate(), today);
            if (daysOverdue > 0) {
                overdueAmount = overdueAmount.add(balance);
            }
            if (daysOverdue > maxDaysOverdue) maxDaysOverdue = daysOverdue;
            if (oldestDueDate == null || inv.getDueDate().isBefore(oldestDueDate)) {
                oldestDueDate = inv.getDueDate();
            }

            invoiceList.add(new OverdueCustomerResponse.OverdueInvoice(
                    inv.getId(),
                    inv.getInvoiceNumber(),
                    inv.getTotalAmount(),
                    balance,
                    inv.getDueDate(),
                    Math.max(0, daysOverdue)
            ));
        }

        Instant lastReminder = reminderLogRepository
                .findLatestByOrgAndContact(orgId, contactId)
                .map(ReminderLog::getSentAt)
                .orElse(null);

        String phone = contact.getMobile() != null && !contact.getMobile().isBlank()
                ? contact.getMobile() : contact.getPhone();

        return new OverdueCustomerResponse(
                contact.getId(),
                contact.getDisplayName(),
                phone,
                totalOutstanding,
                overdueAmount,
                oldestDueDate,
                maxDaysOverdue,
                invoices.size(),
                lastReminder,
                invoiceList
        );
    }

    public List<CustomerRiskResponse> getCustomerRisk() {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();

        List<Invoice> outstandingInvoices = invoiceRepository.findOutstandingInvoices(orgId);
        List<Contact> activeSalesHolds = contactRepository.findActiveCustomerSalesHolds(orgId, today);

        Map<UUID, List<Invoice>> invoicesByContact = outstandingInvoices.stream()
                .collect(Collectors.groupingBy(Invoice::getContactId, LinkedHashMap::new, Collectors.toList()));

        Set<UUID> contactIds = new LinkedHashSet<>(invoicesByContact.keySet());
        activeSalesHolds.forEach(contact -> contactIds.add(contact.getId()));
        if (contactIds.isEmpty()) {
            return List.of();
        }

        Map<UUID, Contact> contactsById = contactRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, contactIds).stream()
                .collect(Collectors.toMap(Contact::getId, contact -> contact));
        activeSalesHolds.forEach(contact -> contactsById.putIfAbsent(contact.getId(), contact));

        return contactIds.stream()
                .map(contactId -> buildCustomerRisk(contactsById.get(contactId),
                        invoicesByContact.getOrDefault(contactId, List.of()), today))
                .filter(Objects::nonNull)
                .sorted(Comparator
                        .comparingInt((CustomerRiskResponse risk) -> riskRank(risk.riskLevel()))
                        .thenComparing(CustomerRiskResponse::overdueAmount, Comparator.reverseOrder())
                        .thenComparing(CustomerRiskResponse::outstandingAr, Comparator.reverseOrder()))
                .toList();
    }

    public ReminderTextResponse generateReminderMessage(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        List<Invoice> invoices = invoiceRepository.findOutstandingByContact(orgId, contactId);
        if (invoices.isEmpty()) {
            throw new BusinessException("No outstanding invoices for this customer", "ERR_NO_OUTSTANDING");
        }

        BigDecimal totalOutstanding = BigDecimal.ZERO;
        LocalDate oldestDueDate = null;

        for (Invoice inv : invoices) {
            BigDecimal balance = inv.getBalanceDue() != null ? inv.getBalanceDue() : inv.getTotalAmount();
            totalOutstanding = totalOutstanding.add(balance);
            if (oldestDueDate == null || inv.getDueDate().isBefore(oldestDueDate)) {
                oldestDueDate = inv.getDueDate();
            }
        }

        // Build the reminder message
        StringBuilder sb = new StringBuilder();
        sb.append("Dear ").append(contact.getDisplayName()).append(",\n\n");
        sb.append("This is a friendly reminder from ").append(org.getName()).append(".\n\n");
        sb.append("Your pending amount: ").append(formatAmount(totalOutstanding)).append("\n");
        if (oldestDueDate != null) {
            sb.append("Overdue since: ").append(oldestDueDate.format(DATE_FMT)).append("\n");
        }
        sb.append("\nPending invoices:\n");

        for (Invoice inv : invoices) {
            BigDecimal balance = inv.getBalanceDue() != null ? inv.getBalanceDue() : inv.getTotalAmount();
            sb.append("- ").append(inv.getInvoiceNumber())
                    .append(": ").append(formatAmount(balance));
            if (inv.getDueDate() != null) {
                sb.append(" (due ").append(inv.getDueDate().format(DATE_FMT)).append(")");
            }
            sb.append("\n");
        }

        sb.append("\nKindly clear the dues at your earliest convenience.\n");

        // Add UPI/bank details from org settings
        Map<String, String> settings = orgSettingsService.getAll(orgId);
        String upiId = settings.get("payment.upi_id");
        String bankName = settings.get("payment.bank_name");
        String accountNo = settings.get("payment.account_no");
        String ifsc = settings.get("payment.ifsc");

        if (upiId != null && !upiId.isBlank()) {
            sb.append("\nUPI: ").append(upiId);
        }
        if (bankName != null && !bankName.isBlank()) {
            sb.append("\nBank: ").append(bankName);
            if (accountNo != null && !accountNo.isBlank()) {
                sb.append(" (A/c: ").append(accountNo).append(")");
            }
            if (ifsc != null && !ifsc.isBlank()) {
                sb.append("\nIFSC: ").append(ifsc);
            }
        }

        sb.append("\n\nThank you for your business!");

        String message = sb.toString();

        // Resolve phone
        String phone = contact.getMobile() != null && !contact.getMobile().isBlank()
                ? contact.getMobile() : contact.getPhone();

        // Build WhatsApp URL
        String whatsappUrl = buildWhatsAppUrl(phone, message);

        return new ReminderTextResponse(
                contact.getId(),
                contact.getDisplayName(),
                phone,
                message,
                whatsappUrl
        );
    }

    @Transactional
    public void markReminderSent(UUID contactId, String channel) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        // Verify contact exists
        contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));

        ReminderLog log = ReminderLog.builder()
                .orgId(orgId)
                .contactId(contactId)
                .sentAt(Instant.now())
                .channel(channel != null && !channel.isBlank() ? channel : "WHATSAPP")
                .sentBy(userId)
                .build();

        reminderLogRepository.save(log);
    }

    // ── Helpers ─────────────────────────────────────────────────

    private String formatAmount(BigDecimal amount) {
        if (amount == null) return "₹0.00";
        return "₹" + amount.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private String buildWhatsAppUrl(String phone, String message) {
        if (phone == null || phone.isBlank()) return "";
        String cleanPhone = phone.replaceAll("[\\s\\-+]", "");
        if (cleanPhone.length() == 10) cleanPhone = "91" + cleanPhone;
        String encoded = URLEncoder.encode(message, StandardCharsets.UTF_8);
        return "https://wa.me/" + cleanPhone + "?text=" + encoded;
    }

    private CustomerRiskResponse buildCustomerRisk(Contact contact, List<Invoice> invoices, LocalDate today) {
        if (contact == null) {
            return null;
        }

        BigDecimal outstanding = BigDecimal.ZERO;
        BigDecimal overdueAmount = BigDecimal.ZERO;
        int overdueCount = 0;
        long maxDaysOverdue = 0;

        for (Invoice invoice : invoices) {
            BigDecimal balance = balanceDue(invoice);
            outstanding = outstanding.add(balance);
            long daysOverdue = ChronoUnit.DAYS.between(invoice.getDueDate(), today);
            if (daysOverdue > 0) {
                overdueAmount = overdueAmount.add(balance);
                overdueCount++;
                maxDaysOverdue = Math.max(maxDaysOverdue, daysOverdue);
            }
        }

        BigDecimal contactOutstanding = contact.getOutstandingAr() != null ? contact.getOutstandingAr() : BigDecimal.ZERO;
        if (outstanding.compareTo(BigDecimal.ZERO) == 0 && contactOutstanding.compareTo(BigDecimal.ZERO) > 0) {
            outstanding = contactOutstanding;
        }

        BigDecimal creditLimit = contact.getCreditLimit() != null ? contact.getCreditLimit() : BigDecimal.ZERO;
        boolean overCredit = creditLimit.compareTo(BigDecimal.ZERO) > 0 && outstanding.compareTo(creditLimit) > 0;
        boolean salesHoldActive = contact.isSalesHold()
                && (contact.getSalesHoldUntil() == null || !contact.getSalesHoldUntil().isBefore(today));

        List<String> reasons = new ArrayList<>();
        if (salesHoldActive) {
            reasons.add("Customer is on sales hold");
        }
        if (overCredit) {
            reasons.add("Outstanding exceeds credit limit");
        }
        if (overdueCount > 0) {
            reasons.add(overdueCount + " overdue invoice(s)");
        }

        String riskLevel = resolveRiskLevel(salesHoldActive, overCredit, overdueCount, outstanding);
        BigDecimal utilization = creditUtilizationPercent(outstanding, creditLimit);
        String phone = contact.getMobile() != null && !contact.getMobile().isBlank()
                ? contact.getMobile() : contact.getPhone();

        return new CustomerRiskResponse(
                contact.getId(),
                contact.getDisplayName(),
                phone,
                creditLimit,
                outstanding,
                overdueAmount,
                invoices.size(),
                overdueCount,
                maxDaysOverdue,
                utilization,
                salesHoldActive,
                contact.getSalesHoldReason(),
                contact.getSalesHoldUntil(),
                riskLevel,
                reasons
        );
    }

    private BigDecimal balanceDue(Invoice invoice) {
        if (invoice.getBalanceDue() != null) {
            return invoice.getBalanceDue();
        }
        return invoice.getTotalAmount() != null ? invoice.getTotalAmount() : BigDecimal.ZERO;
    }

    private BigDecimal creditUtilizationPercent(BigDecimal outstanding, BigDecimal creditLimit) {
        if (creditLimit == null || creditLimit.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }
        return outstanding.multiply(new BigDecimal("100"))
                .divide(creditLimit, 2, RoundingMode.HALF_UP);
    }

    private String resolveRiskLevel(boolean salesHold, boolean overCredit, int overdueCount, BigDecimal outstanding) {
        if (salesHold) {
            return "SALES_HOLD";
        }
        if (overCredit) {
            return "OVER_CREDIT";
        }
        if (overdueCount > 0) {
            return "OVERDUE";
        }
        if (outstanding != null && outstanding.compareTo(BigDecimal.ZERO) > 0) {
            return "WATCH";
        }
        return "OK";
    }

    private int riskRank(String riskLevel) {
        return switch (riskLevel) {
            case "SALES_HOLD" -> 0;
            case "OVER_CREDIT" -> 1;
            case "OVERDUE" -> 2;
            case "WATCH" -> 3;
            default -> 4;
        };
    }
}
