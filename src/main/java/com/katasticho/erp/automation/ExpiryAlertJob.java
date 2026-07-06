package com.katasticho.erp.automation;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.service.NotificationService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBatchBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
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
public class ExpiryAlertJob {

    private final OrganisationRepository orgRepository;
    private final StockBatchRepository batchRepository;
    private final StockBatchBalanceRepository batchBalanceRepository;
    private final ItemRepository itemRepository;
    private final AppUserRepository userRepository;
    private final NotificationService notificationService;
    private final OrgBatchTxRunner txRunner;

    // run() is deliberately NOT @Transactional — each org commits in its own
    // transaction (via txRunner) so one org's failure can't roll back every other
    // org's markExpired flips + alerts or abort the whole sweep.
    @Scheduled(cron = "${app.automation.expiry-alert.cron:0 0 8 * * *}")
    @SchedulerLock(name = "ExpiryAlertJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        LocalDate today = LocalDate.now();
        LocalDate horizon = today.plusDays(30);

        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndActiveTrue();
        for (Organisation org : orgs) {
            try {
                txRunner.runInTx(() -> processOrg(org, today, horizon));
            } catch (Exception e) {
                log.warn("Expiry alert failed for org {}: {}", org.getId(), e.getMessage());
            }
        }
    }

    void processOrg(Organisation org, LocalDate today, LocalDate horizon) {
            batchRepository.markExpired(org.getId(), today);

            List<StockBatch> expiring = batchRepository.findExpiringWithStock(org.getId(), horizon);
            if (expiring.isEmpty()) return;

            AppUser admin = userRepository.findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER")
                    .orElse(null);
            if (admin == null) return;

            int expired = 0, critical = 0, warning = 0;
            List<Map<String, Object>> items = new ArrayList<>();

            for (StockBatch batch : expiring) {
                BigDecimal qty = batchBalanceRepository.findByOrgIdAndBatchId(org.getId(), batch.getId())
                        .stream()
                        .map(StockBatchBalance::getQuantityOnHand)
                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                if (qty.compareTo(BigDecimal.ZERO) <= 0) continue;

                String urgency;
                if (batch.getExpiryDate().isBefore(today)) {
                    urgency = "EXPIRED";
                    expired++;
                } else if (batch.getExpiryDate().isBefore(today.plusDays(8))) {
                    urgency = "CRITICAL";
                    critical++;
                } else {
                    urgency = "WARNING";
                    warning++;
                }

                String itemName = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(batch.getItemId(), org.getId())
                        .map(Item::getName).orElse("Unknown");

                Map<String, Object> entry = new HashMap<>();
                entry.put("itemName", itemName);
                entry.put("batchNumber", batch.getBatchNumber());
                entry.put("expiryDate", batch.getExpiryDate().toString());
                entry.put("quantity", qty);
                entry.put("urgency", urgency);
                items.add(entry);
            }

            if (items.isEmpty()) return;

            String title = String.format("Expiry alert: %d batches expiring", items.size());
            String message = String.format("%d expired, %d expiring within 7 days, %d expiring within 30 days",
                    expired, critical, warning);

            String severity = expired > 0 ? "CRITICAL" : critical > 0 ? "WARNING" : "INFO";
            Map<String, Object> metadata = Map.of("items", items);

            notificationService.send(org.getId(), admin.getId(), title, message,
                    severity, "EXPIRY_ALERT", null, null, metadata);
            log.info("Expiry alerts: {} batches for org {}", items.size(), org.getId());
    }
}
