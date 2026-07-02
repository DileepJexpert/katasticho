package com.katasticho.erp.automation;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.procurement.service.SupplierRateContractService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.LocalDate;

/**
 * Nightly sweep that flips ACTIVE rate contracts past their valid_until date
 * to EXPIRED so the PO drafter stops returning a stale negotiated price.
 *
 * <p>The lookup itself ({@code SupplierRateContractLineRepository.findActiveLine})
 * only joins on status = 'ACTIVE'; the sweep is what makes that filter
 * meaningful over time.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class SupplierRateContractExpiryJob {

    private final OrganisationRepository orgRepository;
    private final SupplierRateContractService supplierRateContractService;
    private final Clock clock;

    @Scheduled(cron = "${app.automation.rate-contract-expiry.cron:0 30 2 * * *}")
    @SchedulerLock(name = "SupplierRateContractExpiryJob", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    public void run() {
        LocalDate today = LocalDate.now(clock);
        int total = 0;

        for (Organisation org : orgRepository.findByIsDeletedFalseAndActiveTrue()) {
            try {
                TenantContext.setCurrentOrgId(org.getId());
                total += supplierRateContractService.sweepExpiredForOrg(org.getId(), today);
            } catch (Exception e) {
                log.warn("Rate contract expiry sweep failed for org {}: {}",
                        org.getId(), e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (total > 0) {
            log.info("Supplier rate contract expiry sweep complete: {} expired", total);
        }
    }
}
