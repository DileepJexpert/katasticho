package com.katasticho.erp.common.service;

import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.common.entity.OrgBootstrapStatus;
import com.katasticho.erp.common.repository.OrgBootstrapStatusRepository;
import com.katasticho.erp.inventory.service.UomService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxSeedService;
import com.katasticho.erp.common.service.FeatureFlagService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

/**
 * Single orchestrator for all org-level seed data.
 *
 * <h3>Bootstrap order is CRITICAL:</h3>
 * <ol>
 *   <li><b>UoMs</b> — needed by item creation later, no dependencies</li>
 *   <li><b>Chart of Accounts</b> — must exist before tax GL accounts can
 *       be resolved. Tax seeding (step 4) calls
 *       {@code findAccountId("2020")} etc.</li>
 *   <li><b>Default Accounts</b> — maps CoA accounts to business purposes
 *       (AR, AP, Sales, Purchase etc.). Requires CoA from step 2.</li>
 *   <li><b>Tax Configuration</b> — links tax rates to GL accounts from
 *       the CoA. Requires accounts from step 2 to exist.</li>
 * </ol>
 *
 * <p>Reversing this order causes:
 * <ul>
 *   <li>Tax rates with null GL accounts (step 4 before step 2)</li>
 *   <li>Default account settings pointing to non-existent accounts
 *       (step 3 before step 2)</li>
 * </ul>
 *
 * <h3>Idempotency contract:</h3>
 * Every seeder is safe to call 100 times. Each returns a
 * {@link SeedResult} indicating what it did. This method does NOT
 * use {@code @Transactional} — each seeder manages its own transaction.
 * If one fails, already-committed seeders remain. The caller can retry.
 *
 * <h3>Error handling:</h3>
 * If a seeder throws, the exception is caught, logged, and the next
 * seeder runs. The org's bootstrap status is recorded in
 * {@code org_bootstrap_status} with {@code PARTIAL_FAILURE} so an
 * admin can re-trigger via the repair endpoint.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrgBootstrapService {

    private final OrganisationRepository organisationRepository;
    private final UomService uomService;
    private final AccountService accountService;
    private final DefaultAccountService defaultAccountService;
    private final TaxSeedService taxSeedService;
    private final FeatureFlagService featureFlagService;
    private final OrgBootstrapStatusRepository statusRepository;

    private final ConcurrentHashMap<UUID, Boolean> verifiedOrgs = new ConcurrentHashMap<>();

    /**
     * Lazily ensures an org has been bootstrapped. Called once per org per
     * app lifecycle (result cached in-memory). If the org has no
     * bootstrap status record, triggers a full bootstrap.
     */
    public void ensureBootstrapped(UUID orgId) {
        verifiedOrgs.computeIfAbsent(orgId, id -> {
            boolean exists = statusRepository.existsById(id);
            if (!exists) {
                log.warn("Org {} has no bootstrap record — running lazy bootstrap", id);
                organisationRepository.findById(id).ifPresent(this::bootstrap);
            }
            return true;
        });
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onStartup() {
        BootstrapAllResult result = bootstrapAll();
        log.info("Bootstrap complete: {} orgs OK, {} orgs repaired, {} failures",
                result.succeeded(), result.repaired(), result.failed());
    }

    public BootstrapAllResult bootstrapAll() {
        List<Organisation> orgs = organisationRepository.findAll();
        List<BootstrapResult> results = new ArrayList<>(orgs.size());
        int ok = 0, repaired = 0, failed = 0;

        for (Organisation org : orgs) {
            BootstrapResult result = bootstrap(org);
            results.add(result);

            if (!result.allSucceeded()) {
                failed++;
            } else if (isUnchanged(result)) {
                ok++;
            } else {
                repaired++;
            }
        }

        return new BootstrapAllResult(orgs.size(), ok, repaired, failed, results);
    }

    public BootstrapResult bootstrap(Organisation org) {
        UUID orgId = org.getId();
        String industryCode = org.getIndustryCode();
        List<String> subCats = org.getSubCategories();
        boolean hasSubCats = subCats != null && !subCats.isEmpty();

        StepOutcome uoms = hasSubCats
                ? runStep("UoMs", orgId, () -> uomService.seedDefaultsForOrg(orgId, subCats))
                : runStep("UoMs", orgId, () -> uomService.seedDefaultsForOrg(orgId, industryCode));

        StepOutcome accounts = runStep("CoA", orgId,
                () -> accountService.seedFromTemplate(orgId, org.getIndustry()));

        StepOutcome defaults = runStep("DefaultAccounts", orgId,
                () -> defaultAccountService.seedDefaultsForOrg(orgId));

        StepOutcome tax = runStep("TaxConfig", orgId,
                () -> taxSeedService.seedForOrg(org));

        StepOutcome features = runStep("FeatureFlags", orgId, () -> {
            if (hasSubCats) {
                featureFlagService.seedForSubCategories(orgId, subCats);
            } else {
                featureFlagService.seedForIndustry(orgId, industryCode);
            }
            return SeedResult.CREATED_NEW;
        });

        boolean allOk = uoms.succeeded() && accounts.succeeded()
                && defaults.succeeded() && tax.succeeded() && features.succeeded();

        String summary = String.format(
                "Org %s bootstrap: UoMs=%s, CoA=%s, DefaultAccounts=%s, TaxConfig=%s, Features=%s",
                orgId, format(uoms), format(accounts), format(defaults), format(tax), format(features));
        log.info(summary);

        recordStatus(orgId, uoms, accounts, defaults, tax, allOk, summary);

        return new BootstrapResult(orgId, uoms, accounts, defaults, tax, allOk, summary);
    }

    private StepOutcome runStep(String name, UUID orgId, Supplier<SeedResult> step) {
        try {
            return StepOutcome.success(step.get());
        } catch (Exception e) {
            log.error("Bootstrap step '{}' failed for org {}: {}", name, orgId, e.getMessage(), e);
            return StepOutcome.failure(e.getMessage());
        }
    }

    private void recordStatus(UUID orgId, StepOutcome uoms, StepOutcome accounts,
                              StepOutcome defaults, StepOutcome tax,
                              boolean allOk, String errorSummary) {
        try {
            OrgBootstrapStatus status = statusRepository.findById(orgId)
                    .orElseGet(() -> OrgBootstrapStatus.builder().orgId(orgId).build());

            Instant now = Instant.now();
            if (uoms.succeeded()) status.setUomsSeededAt(now);
            if (accounts.succeeded()) status.setAccountsSeededAt(now);
            if (defaults.succeeded()) status.setDefaultAccountsSeededAt(now);
            if (tax.succeeded()) status.setTaxConfigSeededAt(now);

            status.setLastBootstrapAt(now);
            status.setLastBootstrapStatus(allOk ? "SUCCESS" : "PARTIAL_FAILURE");

            if (!allOk) {
                StringBuilder errors = new StringBuilder();
                if (!uoms.succeeded()) errors.append("UoMs: ").append(uoms.error()).append("; ");
                if (!accounts.succeeded()) errors.append("CoA: ").append(accounts.error()).append("; ");
                if (!defaults.succeeded()) errors.append("DefaultAccounts: ").append(defaults.error()).append("; ");
                if (!tax.succeeded()) errors.append("TaxConfig: ").append(tax.error()).append("; ");
                status.setLastErrorMessage(errors.toString());
            } else {
                status.setLastErrorMessage(null);
            }

            statusRepository.save(status);
        } catch (Exception e) {
            log.warn("Failed to record bootstrap status for org {}: {}", orgId, e.getMessage());
        }
    }

    private boolean isUnchanged(BootstrapResult result) {
        return result.uoms().result() == SeedResult.ALREADY_EXISTS
                && result.accounts().result() == SeedResult.ALREADY_EXISTS
                && result.defaultAccounts().result() == SeedResult.ALREADY_EXISTS
                && result.taxConfig().result() == SeedResult.ALREADY_EXISTS;
    }

    private String format(StepOutcome outcome) {
        return outcome.succeeded() ? String.valueOf(outcome.result()) : "FAILED(" + outcome.error() + ")";
    }
}
