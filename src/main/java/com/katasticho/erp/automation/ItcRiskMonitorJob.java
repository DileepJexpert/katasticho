package com.katasticho.erp.automation;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.gst.service.ItcRiskMonitorService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

/**
 * Early-month ITC-at-risk sweep — the prevention window the recon tools skip.
 *
 * <p>A supplier's GSTR-1 for month M is due by the 11th of M+1. So on the 5th of
 * each month this scans the <em>previous</em> month's purchase bills against the
 * real-time GSTR-2A feed and pushes an AI-Inbox alert (with a ready supplier
 * nudge) for every registered supplier who hasn't filed yet — before the cutoff
 * locks the credit. Each org runs in its own tenant context; one failure never
 * stops the rest.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ItcRiskMonitorJob {

    private final OrganisationRepository orgRepository;
    private final AppUserRepository userRepository;
    private final ItcRiskMonitorService itcRiskMonitorService;

    @Scheduled(cron = "${app.automation.itc-risk-monitor.cron:0 0 9 5 * *}")
    @SchedulerLock(name = "ItcRiskMonitorJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        // Month whose GSTR-1 deadline (11th) falls in the current month.
        String period = YearMonth.from(LocalDate.now().minusMonths(1)).toString();
        List<Organisation> orgs = orgRepository.findByIsDeletedFalseAndActiveTrue();
        int totalAlerts = 0, orgsTouched = 0;

        for (Organisation org : orgs) {
            AppUser owner = userRepository
                    .findFirstByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER")
                    .orElse(null);
            if (owner == null) continue;

            try {
                TenantContext.setCurrentOrgId(org.getId());
                TenantContext.setCurrentUserId(owner.getId());
                TenantContext.setCurrentRole("SYSTEM");

                int raised = itcRiskMonitorService.refreshAndAlert(period);
                if (raised > 0) {
                    orgsTouched++;
                    totalAlerts += raised;
                }
            } catch (Exception e) {
                log.warn("ITC-risk sweep failed for org {}: {}", org.getId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }

        if (orgsTouched > 0) {
            log.info("ITC-risk sweep {}: {} alert(s) across {} org(s)", period, totalAlerts, orgsTouched);
        }
    }
}
