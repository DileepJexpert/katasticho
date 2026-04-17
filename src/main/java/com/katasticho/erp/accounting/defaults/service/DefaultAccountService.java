package com.katasticho.erp.accounting.defaults.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.dto.DefaultAccountResponse;
import com.katasticho.erp.accounting.defaults.entity.OrgDefaultAccount;
import com.katasticho.erp.accounting.defaults.repository.OrgDefaultAccountRepository;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Per-org "default account" registry. Replaces hardcoded GL codes
 * (e.g. literal "5000" / "2010") in posting services with a lookup
 * keyed by {@link DefaultAccountPurpose}.
 *
 * Lookup precedence inside {@link #get(UUID, DefaultAccountPurpose)}:
 *   1. Explicit row in {@code org_default_account} (user override)
 *   2. Default CoA code from the enum's {@code defaultCode}
 *   3. {@link BusinessException} ERR_DEFAULT_ACCOUNT_MISSING
 *
 * Seeded eagerly on signup + idempotently on startup so existing
 * orgs created before this feature get rows on next boot.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DefaultAccountService {

    private final OrgDefaultAccountRepository repo;
    private final AccountRepository accountRepository;
    private final OrganisationRepository organisationRepository;

    // Run AFTER AccountService(@Order 1) seeds the CoA, BEFORE TaxSeedService(@Order 3).
    // Tax seeding does not depend on default accounts today, but giving us slot 2
    // leaves room without re-shuffling later.
    @EventListener(ApplicationReadyEvent.class)
    @Order(2)
    @Transactional
    public void seedAllOrgs() {
        List<Organisation> orgs = organisationRepository.findAll();
        int touched = 0;
        for (Organisation org : orgs) {
            int added = seedDefaultsForOrg(org.getId());
            if (added > 0) touched++;
        }
        if (touched > 0) {
            log.info("Seeded org_default_account rows for {} org(s)", touched);
        }
    }

    /**
     * Idempotent: inserts one row per missing purpose for the org. Existing
     * rows are never overwritten. Returns count of rows actually inserted.
     */
    @Transactional
    public int seedDefaultsForOrg(UUID orgId) {
        int inserted = 0;
        for (DefaultAccountPurpose purpose : DefaultAccountPurpose.values()) {
            if (repo.existsByOrgIdAndPurpose(orgId, purpose)) continue;

            Optional<Account> account = accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(
                    orgId, purpose.defaultCode());
            if (account.isEmpty()) {
                // CoA template hasn't been seeded yet (or doesn't include this code).
                // Skip silently — the next startup pass will pick it up once the
                // account exists.
                continue;
            }

            OrgDefaultAccount row = OrgDefaultAccount.builder()
                    .orgId(orgId)
                    .purpose(purpose)
                    .accountId(account.get().getId())
                    .build();
            repo.save(row);
            inserted++;
        }
        if (inserted > 0) {
            log.info("Seeded {} default-account rows for org {}", inserted, orgId);
        }
        return inserted;
    }

    /**
     * Returns the {@link Account} bound to a purpose for the org. Falls back
     * to looking up by {@link DefaultAccountPurpose#defaultCode()} if the org
     * has no override row yet (first call before seed completes).
     *
     * @throws BusinessException if neither override nor default code resolves.
     */
    @Transactional(readOnly = true)
    public Account get(UUID orgId, DefaultAccountPurpose purpose) {
        Optional<UUID> overrideId = repo.findByOrgIdAndPurpose(orgId, purpose)
                .map(OrgDefaultAccount::getAccountId);
        if (overrideId.isPresent()) {
            return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, overrideId.get())
                    .orElseThrow(() -> missing(purpose, orgId));
        }
        return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, purpose.defaultCode())
                .orElseThrow(() -> missing(purpose, orgId));
    }

    /** Convenience: same as {@link #get} but returns just the account code. */
    @Transactional(readOnly = true)
    public String getCode(UUID orgId, DefaultAccountPurpose purpose) {
        return get(orgId, purpose).getCode();
    }

    /**
     * Returns the full mapping for an org (purpose → accountId). Purposes
     * without an override row are absent from the map; callers should fall
     * back to {@link DefaultAccountPurpose#defaultCode()}.
     */
    @Transactional(readOnly = true)
    public Map<DefaultAccountPurpose, UUID> getAllOverrides(UUID orgId) {
        Map<DefaultAccountPurpose, UUID> out = new EnumMap<>(DefaultAccountPurpose.class);
        repo.findByOrgId(orgId).forEach(r -> out.put(r.getPurpose(), r.getAccountId()));
        return out;
    }

    /**
     * Upsert: changes which Account is bound to a purpose for the org.
     * Validates the account exists and belongs to the org.
     */
    @Transactional
    public void update(UUID orgId, DefaultAccountPurpose purpose, UUID accountId) {
        Account account = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId)
                .orElseThrow(() -> BusinessException.notFound("Account", accountId));

        OrgDefaultAccount row = repo.findByOrgIdAndPurpose(orgId, purpose)
                .orElseGet(() -> OrgDefaultAccount.builder()
                        .orgId(orgId).purpose(purpose).build());
        row.setAccountId(account.getId());
        repo.save(row);
        log.info("Default account updated: org={} purpose={} → account={} ({})",
                orgId, purpose, account.getCode(), account.getName());
    }

    /**
     * Builds the full Settings → Default Accounts list for an org. One row per
     * {@link DefaultAccountPurpose}; each row reports the currently bound CoA
     * account (override if present, else fallback by default code) and an
     * {@code overridden} flag.
     */
    @Transactional(readOnly = true)
    public List<DefaultAccountResponse> listForOrg(UUID orgId) {
        Map<DefaultAccountPurpose, UUID> overrides = getAllOverrides(orgId);
        List<DefaultAccountResponse> out = new ArrayList<>(DefaultAccountPurpose.values().length);
        for (DefaultAccountPurpose purpose : DefaultAccountPurpose.values()) {
            UUID overrideId = overrides.get(purpose);
            Account account;
            if (overrideId != null) {
                account = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, overrideId)
                        .orElse(null);
            } else {
                account = accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, purpose.defaultCode())
                        .orElse(null);
            }
            out.add(new DefaultAccountResponse(
                    purpose,
                    purpose.label(),
                    purpose.defaultCode(),
                    account != null ? account.getId() : null,
                    account != null ? account.getCode() : null,
                    account != null ? account.getName() : null,
                    overrideId != null
            ));
        }
        return out;
    }

    private BusinessException missing(DefaultAccountPurpose purpose, UUID orgId) {
        return new BusinessException(
                "Default account not configured for purpose " + purpose
                        + " (org=" + orgId + "). Set it in Settings → Accounting → Default Accounts.",
                "ERR_DEFAULT_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST);
    }
}
