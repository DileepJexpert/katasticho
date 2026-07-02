package com.katasticho.erp.automation;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.ai.service.ProactiveAgentService;
import com.katasticho.erp.ai.service.ProactiveAgentService.ProactiveRunResult;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Runs the proactive agents (collections reminders, month-close checklist,
 * anomaly sweep) for every active org once a day. Each org runs in its own
 * tenant context; one org's failure never stops the rest.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ProactiveAgentJob {

    private final OrganisationRepository orgRepository;
    private final AppUserRepository userRepository;
    private final ProactiveAgentService proactiveAgentService;

    @Scheduled(cron = "${app.automation.proactive-agents.cron:0 30 6 * * *}")
    @SchedulerLock(name = "ProactiveAgentJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndActiveTrue();
        int totalCollections = 0, totalMonthClose = 0, totalAnomalies = 0, totalFlux = 0,
                totalCategorize = 0, orgsTouched = 0;

        for (Organisation org : orgs) {
            AppUser owner = userRepository
                    .findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER")
                    .orElse(null);
            if (owner == null) continue;

            try {
                TenantContext.setCurrentOrgId(org.getId());
                TenantContext.setCurrentUserId(owner.getId());
                TenantContext.setCurrentRole("SYSTEM");

                ProactiveRunResult r = proactiveAgentService.runAll();
                totalCategorize += r.categorize();
                if (r.collections() + r.monthClose() + r.anomalies() + r.flux() > 0) {
                    orgsTouched++;
                    totalCollections += r.collections();
                    totalMonthClose += r.monthClose();
                    totalAnomalies += r.anomalies();
                    totalFlux += r.flux();
                }
            } catch (Exception e) {
                log.warn("Proactive sweep failed for org {}: {}", org.getId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }

        if (orgsTouched > 0 || totalCategorize > 0) {
            log.info("Proactive sweep: {} collections, {} month-close, {} anomalies, {} flux, "
                    + "{} categorize patterns across {} org(s)",
                    totalCollections, totalMonthClose, totalAnomalies, totalFlux, totalCategorize, orgsTouched);
        }
    }
}
