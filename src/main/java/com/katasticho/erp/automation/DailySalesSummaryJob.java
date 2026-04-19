package com.katasticho.erp.automation;

import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.service.NotificationService;
import com.katasticho.erp.expense.repository.ExpenseRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class DailySalesSummaryJob {

    private final OrganisationRepository orgRepository;
    private final InvoiceRepository invoiceRepository;
    private final PaymentRepository paymentRepository;
    private final SalesReceiptRepository salesReceiptRepository;
    private final ExpenseRepository expenseRepository;
    private final VendorPaymentRepository vendorPaymentRepository;
    private final StockMovementRepository stockMovementRepository;
    private final ItemRepository itemRepository;
    private final AppUserRepository userRepository;
    private final NotificationService notificationService;

    @Scheduled(cron = "${app.automation.daily-summary.cron:0 0 21 * * *}")
    @Transactional(readOnly = true)
    public void run() {
        LocalDate today = LocalDate.now();
        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndIsActiveTrue();
        int orgCount = 0;

        for (Organisation org : orgs) {
            AppUser admin = userRepository.findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "ADMIN")
                    .orElse(null);
            if (admin == null) continue;

            BigDecimal invoiceRevenue = invoiceRepository.sumRevenueByOrgAndDateRange(org.getId(), today, today);
            BigDecimal receiptRevenue = salesReceiptRepository.sumTotalByOrgAndDate(org.getId(), today);
            BigDecimal revenue = invoiceRevenue.add(receiptRevenue);

            BigDecimal arCollections = paymentRepository.sumCollectedByOrgAndDateRange(org.getId(), today, today);
            BigDecimal collections = arCollections.add(receiptRevenue);

            BigDecimal expenseTotal = expenseRepository.sumTotalByOrgAndDate(org.getId(), today);
            BigDecimal vendorPaymentTotal = vendorPaymentRepository.sumAmountByOrgAndDate(org.getId(), today);
            BigDecimal expenses = expenseTotal.add(vendorPaymentTotal);

            long invoiceCount = invoiceRepository.countByOrgAndDate(org.getId(), today);
            long receiptCount = salesReceiptRepository.countByOrgAndDate(org.getId(), today);

            if (revenue.signum() == 0 && collections.signum() == 0
                    && expenses.signum() == 0 && invoiceCount == 0 && receiptCount == 0) {
                continue;
            }

            List<Map<String, Object>> topItems = new ArrayList<>();
            List<StockMovementRepository.TopSellingRow> topSelling =
                    stockMovementRepository.findTopSellingByDate(org.getId(), today);
            for (var row : topSelling) {
                String name = itemRepository.findById(row.getItemId())
                        .map(Item::getName).orElse("Unknown");
                Map<String, Object> entry = new HashMap<>();
                entry.put("name", name);
                entry.put("qtySold", row.getQtySold());
                topItems.add(entry);
            }

            orgCount++;
            String title = String.format("Daily summary: ₹%s revenue", revenue.toPlainString());
            String message = String.format(
                    "Revenue ₹%s | Collected ₹%s | Expenses ₹%s | %d invoices | %d counter sales",
                    revenue.toPlainString(), collections.toPlainString(),
                    expenses.toPlainString(), invoiceCount, receiptCount);

            Map<String, Object> metadata = new HashMap<>();
            metadata.put("revenue", revenue);
            metadata.put("collections", collections);
            metadata.put("expenses", expenses);
            metadata.put("invoiceCount", invoiceCount);
            metadata.put("receiptCount", receiptCount);
            metadata.put("topItems", topItems);

            notificationService.send(org.getId(), admin.getId(), title, message,
                    "INFO", "DAILY_SUMMARY", null, null, metadata);
        }

        if (orgCount > 0) {
            log.info("Daily summaries sent for {} orgs", orgCount);
        }
    }
}
