package com.katasticho.erp.tax.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxSeedService;
import com.katasticho.erp.tax.dto.TaxAccountMappingResponse;
import com.katasticho.erp.tax.dto.UpdateTaxAccountMappingsRequest;
import com.katasticho.erp.tax.entity.TaxRate;
import com.katasticho.erp.tax.repository.TaxConfigurationRepository;
import com.katasticho.erp.tax.repository.TaxRateRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Settings → Taxes & Compliance → Tax Account Mapping.
 *
 * - {@link #listForOrg}: returns one row per active TaxRate with its bound
 *   input/output GL accounts and a {@code customized} flag.
 * - {@link #updateMappings}: bulk upsert of (taxRateId → glInput, glOutput).
 *   Sets {@code is_gl_account_customized = TRUE} on every touched row, so
 *   {@link TaxSeedService}'s startup repair never overwrites the user's edit.
 * - {@link #resetForOrg}: drops all customisations for the org and re-runs
 *   the country-specific seed defaults.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TaxAccountMappingService {

    private final TaxRateRepository taxRateRepository;
    private final TaxConfigurationRepository taxConfigRepository;
    private final AccountRepository accountRepository;
    private final OrganisationRepository organisationRepository;
    private final TaxSeedService taxSeedService;

    @Transactional(readOnly = true)
    public List<TaxAccountMappingResponse> listForOrg(UUID orgId) {
        List<TaxRate> rates = taxRateRepository.findByOrgIdAndActiveTrue(orgId);

        // Bulk-load referenced accounts in one query each instead of N+1.
        Map<UUID, Account> accountById = new HashMap<>();
        for (TaxRate r : rates) {
            collectAccount(orgId, r.getGlInputAccountId(), accountById);
            collectAccount(orgId, r.getGlOutputAccountId(), accountById);
        }

        List<TaxAccountMappingResponse> out = new ArrayList<>(rates.size());
        for (TaxRate r : rates) {
            Account out_acc = accountById.get(r.getGlOutputAccountId());
            Account in_acc  = accountById.get(r.getGlInputAccountId());
            out.add(new TaxAccountMappingResponse(
                    r.getId(),
                    r.getName(),
                    r.getRateCode(),
                    r.getPercentage(),
                    r.getTaxType(),
                    r.getGlOutputAccountId(),
                    out_acc != null ? out_acc.getCode() : null,
                    out_acc != null ? out_acc.getName() : null,
                    r.getGlInputAccountId(),
                    in_acc != null ? in_acc.getCode() : null,
                    in_acc != null ? in_acc.getName() : null,
                    r.isRecoverable(),
                    r.isGlAccountCustomized()
            ));
        }
        return out;
    }

    @Transactional
    public List<TaxAccountMappingResponse> updateMappings(
            UUID orgId, UpdateTaxAccountMappingsRequest request) {
        for (UpdateTaxAccountMappingsRequest.Mapping m : request.mappings()) {
            TaxRate rate = taxRateRepository.findById(m.taxRateId())
                    .orElseThrow(() -> BusinessException.notFound("TaxRate", m.taxRateId()));
            if (!rate.getOrgId().equals(orgId)) {
                throw new BusinessException(
                        "TaxRate does not belong to this org", "TAX_RATE_FOREIGN",
                        HttpStatus.FORBIDDEN);
            }

            if (m.glOutputAccountId() != null) {
                requireOrgAccount(orgId, m.glOutputAccountId());
            }
            if (m.glInputAccountId() != null) {
                requireOrgAccount(orgId, m.glInputAccountId());
            }

            rate.setGlOutputAccountId(m.glOutputAccountId());
            rate.setGlInputAccountId(m.glInputAccountId());
            rate.setGlAccountCustomized(true);
            taxRateRepository.save(rate);
        }
        log.info("Updated {} tax rate GL mappings for org {}", request.mappings().size(), orgId);
        return listForOrg(orgId);
    }

    /**
     * Reset all tax rate GL mappings for the org back to the seed defaults.
     * Clears the {@code is_gl_account_customized} flag so future seed repairs
     * resume control. Re-runs the country-specific seed if no rates exist yet.
     */
    @Transactional
    public List<TaxAccountMappingResponse> resetForOrg(UUID orgId) {
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        List<TaxRate> existing = taxRateRepository.findByOrgId(orgId);
        if (existing.isEmpty()) {
            // First-time use after reset / brand-new org with no tax data.
            taxSeedService.seedForOrg(org);
            return listForOrg(orgId);
        }

        // Wipe customisation flags + null the GL accounts so the seeder
        // (called next) can re-point them by rate_code via the repair pass.
        for (TaxRate r : existing) {
            r.setGlAccountCustomized(false);
            r.setGlInputAccountId(null);
            r.setGlOutputAccountId(null);
        }
        taxRateRepository.saveAll(existing);

        // Repair pass — same logic as startup seeding, so behaviour is identical
        // to a freshly-seeded org. We don't have direct access to the repair
        // method, so trigger the public entry point.
        taxSeedService.seedAllOrgs();

        log.info("Reset tax account mappings for org {} ({} rates)", orgId, existing.size());
        return listForOrg(orgId);
    }

    private void collectAccount(UUID orgId, UUID accountId, Map<UUID, Account> sink) {
        if (accountId == null || sink.containsKey(accountId)) return;
        accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId)
                .ifPresent(a -> sink.put(accountId, a));
    }

    private Account requireOrgAccount(UUID orgId, UUID accountId) {
        return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId)
                .orElseThrow(() -> BusinessException.notFound("Account", accountId));
    }
}
