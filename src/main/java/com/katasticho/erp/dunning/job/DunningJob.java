package com.katasticho.erp.dunning.job;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.dunning.dto.DunningDtos.DunningRunResult;
import com.katasticho.erp.dunning.service.DunningService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Daily dunning sweep: per active org (opt-out setting {@code dunning.enabled}),
 * fire the applicable escalating overdue reminders. Inert for orgs that have not
 * configured any dunning levels. ShedLock-guarded so two replicas don't double-send.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DunningJob {

    private final OrganisationRepository organisationRepository;
    private final OrgSettingsService orgSettingsService;
    private final DunningService dunningService;

    @Scheduled(cron = "${app.automation.dunning.cron:0 0 10 * * *}")
    @SchedulerLock(name = "DunningJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        int totalSent = 0;
        for (Organisation org : organisationRepository.findByIsDeletedFalseAndActiveTrue()) {
            if (!Boolean.parseBoolean(orgSettingsService.get(org.getId(), "dunning.enabled", "true"))) {
                continue;
            }
            try {
                TenantContext.setCurrentOrgId(org.getId());
                TenantContext.setCurrentRole("SYSTEM");
                DunningRunResult result = dunningService.runForOrg(org.getId());
                totalSent += result.sent();
            } catch (Exception e) {
                log.warn("Dunning sweep failed for org {}: {}", org.getId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (totalSent > 0) {
            log.info("Dunning notices sent: {}", totalSent);
        }
    }
}
