package com.katasticho.erp.automation;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.courier.service.CourierTrackingService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Polls in-flight courier shipments for every active org and applies any status
 * advance. The backstop for couriers without webhooks (and a safety net when a
 * webhook is missed). Each org runs in its own tenant context; one org's failure
 * never stops the rest. Inert for orgs with no courier configured (the service
 * skips unconfigured partners).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class CourierTrackingJob {

    private final OrganisationRepository orgRepository;
    private final AppUserRepository userRepository;
    private final CourierTrackingService trackingService;

    @Scheduled(cron = "${app.automation.courier-tracking.cron:0 0/30 * * * *}")  // every 30 min
    @SchedulerLock(name = "CourierTrackingJob", lockAtMostFor = "PT20M", lockAtLeastFor = "PT30S")
    public void run() {
        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndActiveTrue();
        int totalUpdated = 0, orgsTouched = 0;

        for (Organisation org : orgs) {
            AppUser owner = userRepository
                    .findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER")
                    .orElse(null);
            if (owner == null) continue;
            try {
                TenantContext.setCurrentOrgId(org.getId());
                TenantContext.setCurrentUserId(owner.getId());
                TenantContext.setCurrentRole("SYSTEM");
                int updated = trackingService.syncOrg();
                if (updated > 0) {
                    orgsTouched++;
                    totalUpdated += updated;
                }
            } catch (Exception e) {
                log.warn("Courier tracking poll failed for org {}: {}", org.getId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (orgsTouched > 0) {
            log.info("Courier tracking poll: {} shipment(s) updated across {} org(s)",
                    totalUpdated, orgsTouched);
        }
    }
}
