package com.katasticho.erp.automation;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;

/**
 * Posts post-dated vouchers whose effective date has arrived (Tally PDV
 * parity). Each entry posts in its own tenant context with the original
 * author as actor; a closed period or any other failure skips that entry
 * (it stays DRAFT and is retried tomorrow) without stopping the rest.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class PostDatedJournalJob {

    private final JournalEntryRepository journalEntryRepository;
    private final JournalService journalService;

    @Scheduled(cron = "${app.automation.post-dated-journals.cron:0 15 0 * * *}")
    public void run() {
        List<JournalEntry> due = journalEntryRepository
                .findByStatusAndPostDatedTrueAndEffectiveDateLessThanEqual("DRAFT", LocalDate.now());
        if (due.isEmpty()) return;

        int posted = 0;
        for (JournalEntry entry : due) {
            try {
                TenantContext.setCurrentOrgId(entry.getOrgId());
                TenantContext.setCurrentUserId(entry.getCreatedBy());
                TenantContext.setCurrentRole("SYSTEM");
                journalService.postEntry(entry.getId());
                posted++;
            } catch (Exception e) {
                log.warn("Post-dated journal {} not posted ({}): {}",
                        entry.getEntryNumber(), entry.getOrgId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        log.info("Post-dated journals: {} of {} due posted", posted, due.size());
    }
}
