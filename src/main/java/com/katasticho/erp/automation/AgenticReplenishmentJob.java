package com.katasticho.erp.automation;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.supplychain.agent.AgenticReplenishmentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Daily sweep that runs {@link AgenticReplenishmentService#runForOrg()} for
 * every active org. Each org runs in its own tenant context; one org's
 * failure never wedges the rest. Opt-in via the per-org setting
 * {@code replenishment.agent.enabled} (default false).
 *
 * <p>The job NEVER posts a real PR / PO — it only writes
 * {@code AGENTIC_REPLENISHMENT} suggestions into the AI Inbox. A human
 * approves through {@code AgenticReplenishmentController.approve} to turn
 * any of them into actual documents.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class AgenticReplenishmentJob {

    private final OrganisationRepository orgRepository;
    private final AppUserRepository userRepository;
    private final AgenticReplenishmentService service;

    @Scheduled(cron = "${app.automation.replenishment-agent.cron:0 0 7 * * *}")
    @SchedulerLock(name = "AgenticReplenishmentJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndActiveTrue();
        int totalCreated = 0;
        int orgsRun = 0;
        for (Organisation org : orgs) {
            AppUser owner = userRepository
                    .findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER")
                    .orElse(null);
            if (owner == null) continue;
            try {
                TenantContext.setCurrentOrgId(org.getId());
                TenantContext.setCurrentUserId(owner.getId());
                TenantContext.setCurrentRole("SYSTEM");
                int created = service.runForOrg();
                if (created > 0) {
                    totalCreated += created;
                    orgsRun++;
                }
            } catch (Exception e) {
                log.warn("Replenishment sweep failed for org {}: {}", org.getId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (totalCreated > 0) {
            log.info("Agentic replenishment sweep: {} suggestion(s) across {} org(s)",
                    totalCreated, orgsRun);
        }
    }
}
