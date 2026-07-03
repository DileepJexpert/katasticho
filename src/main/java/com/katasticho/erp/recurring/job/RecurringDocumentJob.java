package com.katasticho.erp.recurring.job;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.recurring.service.RecurringBillService;
import com.katasticho.erp.recurring.service.RecurringJournalService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Daily sweep that generates due recurring bills + recurring journals — the
 * sibling of {@code RecurringInvoiceJob}. One ShedLock-guarded job covers both
 * document types (each template is processed in its own transaction inside the
 * service, so a bad template can't poison the batch). The per-row tenant
 * context is set manually — there is no HTTP filter to do it here.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class RecurringDocumentJob {

    private final RecurringBillService recurringBillService;
    private final RecurringJournalService recurringJournalService;

    /** Daily at 06:05 (server time) — just after the recurring-invoice sweep. */
    @Scheduled(cron = "${app.recurring-document.cron:0 5 6 * * *}")
    @SchedulerLock(name = "RecurringDocumentJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void generateDueDocuments() {
        int bills = sweepBills();
        int journals = sweepJournals();
        if (bills + journals > 0) {
            log.info("RecurringDocumentJob: generated {} bill(s) + {} journal(s)", bills, journals);
        }
    }

    private int sweepBills() {
        var due = recurringBillService.findDueTemplates();
        int ok = 0;
        for (RecurringBillService.DueTemplate t : due) {
            try {
                TenantContext.setCurrentOrgId(t.orgId());
                TenantContext.setCurrentUserId(t.createdBy());
                TenantContext.setCurrentRole("SYSTEM");
                recurringBillService.generateFromTemplate(t.id());
                ok++;
            } catch (Exception e) {
                log.error("RecurringDocumentJob: bill template {} failed — {}", t.id(), e.getMessage(), e);
            } finally {
                TenantContext.clear();
            }
        }
        return ok;
    }

    private int sweepJournals() {
        var due = recurringJournalService.findDueTemplates();
        int ok = 0;
        for (RecurringJournalService.DueTemplate t : due) {
            try {
                TenantContext.setCurrentOrgId(t.orgId());
                TenantContext.setCurrentUserId(t.createdBy());
                TenantContext.setCurrentRole("SYSTEM");
                recurringJournalService.generateFromTemplate(t.id());
                ok++;
            } catch (Exception e) {
                log.error("RecurringDocumentJob: journal template {} failed — {}", t.id(), e.getMessage(), e);
            } finally {
                TenantContext.clear();
            }
        }
        return ok;
    }
}
