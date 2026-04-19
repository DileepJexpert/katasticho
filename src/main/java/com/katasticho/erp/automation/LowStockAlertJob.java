package com.katasticho.erp.automation;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.service.NotificationService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class LowStockAlertJob {

    private final OrganisationRepository orgRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final ItemRepository itemRepository;
    private final ContactRepository contactRepository;
    private final AppUserRepository userRepository;
    private final NotificationService notificationService;

    @Scheduled(cron = "${app.automation.low-stock-alert.cron:0 0 8 * * *}")
    @Transactional(readOnly = true)
    public void run() {
        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndIsActiveTrue();
        int itemCount = 0;
        int orgCount = 0;

        for (Organisation org : orgs) {
            List<StockBalance> lowStock = stockBalanceRepository.findLowStock(org.getId());
            if (lowStock.isEmpty()) continue;

            AppUser admin = userRepository.findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "ADMIN")
                    .orElse(null);
            if (admin == null) continue;

            List<Map<String, Object>> items = new ArrayList<>();
            for (StockBalance sb : lowStock) {
                Item item = itemRepository.findById(sb.getItemId()).orElse(null);
                if (item == null || item.getReorderLevel().signum() <= 0) continue;

                Map<String, Object> entry = new HashMap<>();
                entry.put("itemName", item.getName());
                entry.put("sku", item.getSku());
                entry.put("currentQty", sb.getQuantityOnHand());
                entry.put("reorderLevel", item.getReorderLevel());
                entry.put("reorderQty", item.getReorderQuantity());

                if (item.getPreferredVendorId() != null) {
                    contactRepository.findById(item.getPreferredVendorId())
                            .map(Contact::getDisplayName)
                            .ifPresent(name -> entry.put("preferredVendorName", name));
                }
                items.add(entry);
            }

            if (items.isEmpty()) continue;
            orgCount++;
            itemCount += items.size();

            String title = String.format("Low stock: %d items need reorder", items.size());
            String message = String.format("%d items below reorder level", items.size());
            Map<String, Object> metadata = Map.of("items", items);

            notificationService.send(org.getId(), admin.getId(), title, message,
                    "WARNING", "LOW_STOCK_ALERT", null, null, metadata);
        }

        if (itemCount > 0) {
            log.info("Low stock alerts: {} items across {} orgs", itemCount, orgCount);
        }
    }
}
