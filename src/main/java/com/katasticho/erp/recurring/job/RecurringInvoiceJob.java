package com.katasticho.erp.recurring.job;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.recurring.service.RecurringInvoiceService;
import com.katasticho.erp.recurring.service.RecurringInvoiceService.DueTemplate;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Fires every morning at 06:00 server time to generate DRAFT
 * invoices from every ACTIVE recurring-invoice template whose
 * {@code next_invoice_date} is today or earlier. Each template is
 * processed in its own transaction via
 * {@link RecurringInvoiceService#generateFromTemplate} so one
 * misconfigured template can't poison the rest of the batch.
 *
 * Scheduler sets the per-row tenant context manually — there's no
 * HTTP filter to do it for us here.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class RecurringInvoiceJob {

    private final RecurringInvoiceService recurringInvoiceService;

    /**
     * Daily at 06:00 (server time). Cron: sec min hour dom mon dow.
     * Override with {@code app.recurring-invoice.cron} if needed.
     */
    @Scheduled(cron = "${app.recurring-invoice.cron:0 0 6 * * *}")
    public void generateDueInvoices() {
        List<DueTemplate> due = recurringInvoiceService.findDueTemplates();
        if (due.isEmpty()) {
            log.debug("RecurringInvoiceJob: nothing due");
            return;
        }

        log.info("RecurringInvoiceJob: {} template(s) due — generating", due.size());
        int ok = 0;
        int failed = 0;

        for (DueTemplate t : due) {
            try {
                // Populate tenant context for this org — required by
                // InvoiceService and the audit/comment services.
                TenantContext.setCurrentOrgId(t.orgId());
                TenantContext.setCurrentUserId(t.createdBy());
                TenantContext.setCurrentRole("SYSTEM");

                recurringInvoiceService.generateFromTemplate(t.id());
                ok++;
            } catch (Exception e) {
                failed++;
                log.error("RecurringInvoiceJob: template {} failed — {}",
                        t.id(), e.getMessage(), e);
            } finally {
                TenantContext.clear();
            }
        }

        log.info("RecurringInvoiceJob: done. ok={}, failed={}", ok, failed);
    }
}
