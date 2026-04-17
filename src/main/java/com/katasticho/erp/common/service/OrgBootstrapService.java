package com.katasticho.erp.common.service;

import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.inventory.service.UomService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxSeedService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrgBootstrapService {

    private final OrganisationRepository organisationRepository;
    private final UomService uomService;
    private final AccountService accountService;
    private final DefaultAccountService defaultAccountService;
    private final TaxSeedService taxSeedService;

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void bootstrapAllOrgs() {
        List<Organisation> orgs = organisationRepository.findAll();
        int bootstrapped = 0;
        for (Organisation org : orgs) {
            if (bootstrap(org)) bootstrapped++;
        }
        if (bootstrapped > 0) {
            log.info("Bootstrapped {} org(s) on startup", bootstrapped);
        }
    }

    /**
     * Idempotent bootstrap: seeds UoMs, CoA, default accounts, and tax
     * configuration for the given org. Each step has its own idempotency
     * guard, so calling this multiple times is safe.
     *
     * @return true if any data was actually seeded
     */
    @Transactional
    public boolean bootstrap(Organisation org) {
        boolean changed = false;
        uomService.seedDefaultsForOrg(org.getId());
        int accounts = accountService.seedFromTemplate(org.getId(), org.getIndustry());
        changed |= accounts > 0;
        int defaults = defaultAccountService.seedDefaultsForOrg(org.getId());
        changed |= defaults > 0;
        changed |= taxSeedService.seedForOrg(org);
        return changed;
    }
}
