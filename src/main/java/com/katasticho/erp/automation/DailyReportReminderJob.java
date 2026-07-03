package com.katasticho.erp.automation;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.fieldsales.entity.DcrReport;
import com.katasticho.erp.fieldsales.entity.RouteExecution;
import com.katasticho.erp.fieldsales.repository.DcrReportRepository;
import com.katasticho.erp.fieldsales.repository.RouteExecutionRepository;
import com.katasticho.erp.notification.push.PushNotificationService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.*;

/**
 * Evening nudge for field salespeople who worked a route today but have
 * not submitted their daily report (DCR) yet. Vertical-neutral: applies
 * to anyone with a route execution today. Opt-out per org via setting
 * `field_sales.daily_report_reminder=false`.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DailyReportReminderJob {

    private final OrganisationRepository orgRepository;
    private final RouteExecutionRepository routeExecutionRepository;
    private final DcrReportRepository dcrReportRepository;
    private final OrgSettingsService orgSettingsService;
    private final PushNotificationService pushNotificationService;

    @Scheduled(cron = "${app.automation.daily-report-reminder.cron:0 30 18 * * *}")
    @SchedulerLock(name = "DailyReportReminderJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        LocalDate today = LocalDate.now();
        int reminded = 0;

        for (Organisation org : orgRepository.findByIsDeletedFalseAndActiveTrue()) {
            if (!Boolean.parseBoolean(orgSettingsService.get(
                    org.getId(), "field_sales.daily_report_reminder", "true"))) {
                continue;
            }
            try {
                TenantContext.setCurrentOrgId(org.getId());

                Set<UUID> salespeople = new HashSet<>();
                for (RouteExecution exec : routeExecutionRepository
                        .findByOrgIdAndExecutionDateAndIsDeletedFalse(org.getId(), today)) {
                    salespeople.add(exec.getSalespersonId());
                }

                for (UUID salespersonId : salespeople) {
                    String status = dcrReportRepository
                            .findByOrgIdAndSalespersonIdAndReportDateAndIsDeletedFalse(
                                    org.getId(), salespersonId, today)
                            .map(DcrReport::getStatus)
                            .orElse("MISSING");
                    if ("SUBMITTED".equals(status) || "APPROVED".equals(status)) continue;

                    pushNotificationService.sendToUser(salespersonId,
                            "Daily report pending",
                            "Your daily report for " + today + " has not been submitted yet."
                                    + " Open the field app to review and submit it.",
                            Map.of("type", "DAILY_REPORT_REMINDER", "date", today.toString()));
                    reminded++;
                }
            } catch (Exception e) {
                log.warn("Daily report reminder failed for org {}: {}", org.getId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (reminded > 0) {
            log.info("Daily report reminders sent: {}", reminded);
        }
    }
}
