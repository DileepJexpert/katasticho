package com.katasticho.erp.automation;

import com.katasticho.erp.asset.service.FixedAssetService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.YearMonth;

/**
 * Monthly auto-depreciation. On the 1st of each month posts the previous
 * (just-closed) month's book depreciation for every org that has opted in via
 * the setting {@code assets.auto_depreciation=true} (default off). Delegates to
 * the existing {@link FixedAssetService#runDepreciation}, which is idempotent
 * per (asset, period) — so a re-run or a manual run for the same month posts
 * nothing. ShedLock keeps two replicas from double-posting.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DepreciationJob {

    static final String ENABLED_SETTING = "assets.auto_depreciation";

    private final OrganisationRepository orgRepository;
    private final OrgSettingsService orgSettingsService;
    private final FixedAssetService fixedAssetService;

    @Scheduled(cron = "${app.automation.depreciation.cron:0 30 1 1 * *}")
    @SchedulerLock(name = "DepreciationJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        YearMonth prev = YearMonth.from(LocalDate.now()).minusMonths(1);
        int posted = 0;

        for (Organisation org : orgRepository.findByIsDeletedFalseAndActiveTrue()) {
            if (!Boolean.parseBoolean(orgSettingsService.get(org.getId(), ENABLED_SETTING, "false"))) {
                continue;
            }
            try {
                TenantContext.setCurrentOrgId(org.getId());
                TenantContext.setCurrentRole("SYSTEM");
                fixedAssetService.runDepreciation(prev.getYear(), prev.getMonthValue());
                posted++;
            } catch (Exception e) {
                // A closed period / config hiccup for one org logs + is retried
                // next month; never poison the whole sweep.
                log.warn("Depreciation run failed for org {} period {}: {}",
                        org.getId(), prev, e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (posted > 0) {
            log.info("Auto-depreciation posted for {} org(s), period {}", posted, prev);
        }
    }
}
