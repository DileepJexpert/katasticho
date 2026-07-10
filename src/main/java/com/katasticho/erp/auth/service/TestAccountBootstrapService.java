package com.katasticho.erp.auth.service;

import com.katasticho.erp.auth.dto.AccountSubmissionResponse;
import com.katasticho.erp.auth.dto.RegisterRequest;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.entity.OrgBootstrapStatus;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.repository.OrgBootstrapStatusRepository;
import com.katasticho.erp.common.service.FeatureFlagService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * Seeds ONE fixed QA login (org + OWNER) with every module enabled, so a
 * developer always has a known account to sign in with for manual testing and
 * bug-fixing. Mirrors {@code PlatformAdminBootstrapService} — config-gated, off
 * by default, idempotent, and it never touches real signups or existing users.
 *
 * <p>Unlike the platform admin (a super-admin with no org), this is a normal
 * org OWNER created through the real {@link AuthService#register} path, so it
 * gets the full CoA / default accounts / warehouse / feature-flag bootstrap and
 * can actually drive every org screen (POS, invoices, HR, manufacturing, ...).
 * All module feature flags are then flipped on so the QA user sees every module
 * regardless of the org's industry gating.
 *
 * <p>Runs as an {@link ApplicationRunner} (after Flyway + full context init) so
 * the schema and all beans are ready. Enable ONLY in dev/test — the password is
 * a known constant. Set {@code TEST_ACCOUNT_ENABLED=true} to activate.
 */
@Component
@Order(100)
@RequiredArgsConstructor
@Slf4j
public class TestAccountBootstrapService implements ApplicationRunner {

    /** Every module code — the QA account gets them all so nothing is hidden. */
    private static final List<String> ALL_MODULES = List.of(
            ModuleCode.ACCOUNTING, ModuleCode.AR, ModuleCode.AP, ModuleCode.GST,
            ModuleCode.BANK_RECON, ModuleCode.AI_INBOX, ModuleCode.REPORTS,
            ModuleCode.COLLECTIONS, ModuleCode.POS, ModuleCode.INVENTORY,
            ModuleCode.DISTRIBUTION, ModuleCode.PHARMA, ModuleCode.MANUFACTURING,
            ModuleCode.RECURRING_BILLING, ModuleCode.MULTI_ENTITY, ModuleCode.PAYMENTS,
            ModuleCode.BATCH_EXPIRY, ModuleCode.CA_CONSOLE, ModuleCode.PAYROLL,
            ModuleCode.FIELD_SALES, ModuleCode.PARTNER_NETWORK, ModuleCode.SUPPLY_CHAIN,
            ModuleCode.COURIER, ModuleCode.TRANSPORT);

    private final AuthService authService;
    private final AppUserRepository userRepository;
    private final FeatureFlagService featureFlagService;
    private final OrgBootstrapStatusRepository bootstrapStatusRepository;

    @Value("${app.test-account.enabled:false}")
    private boolean enabled;

    @Value("${app.test-account.phone:}")
    private String phone;

    @Value("${app.test-account.password:}")
    private String password;

    @Value("${app.test-account.full-name:Test QA Owner}")
    private String fullName;

    @Value("${app.test-account.org-name:Test QA Company}")
    private String orgName;

    @Value("${app.test-account.business-type:DISTRIBUTOR}")
    private String businessType;

    @Value("${app.test-account.country-code:IN}")
    private String countryCode;

    @Override
    public void run(ApplicationArguments args) {
        if (!enabled) {
            log.info("Test-account bootstrap skipped — app.test-account.enabled is false");
            return;
        }
        if (isBlank(phone) || isBlank(password)) {
            log.warn("Test-account bootstrap skipped — phone or password not set");
            return;
        }
        if (userRepository.existsByPhoneAndIsDeletedFalse(phone)) {
            log.info("Test-account bootstrap skipped — account for {} already exists", phone);
            return;
        }

        try {
            AccountSubmissionResponse created = authService.register(new RegisterRequest(
                    phone, password, fullName, orgName, businessType,
                    /* industryCode */ null, /* subCategories */ List.of(), countryCode));
            UUID orgId = created.orgId();

            // Flip every module on so the QA login sees the whole app regardless
            // of the seeded industry gating (register bootstraps a per-industry
            // subset). enable() upserts + invalidates the feature cache.
            for (String module : ALL_MODULES) {
                featureFlagService.enable(orgId, module);
            }

            // Skip the onboarding wizard so the login lands straight in the app.
            OrgBootstrapStatus status = bootstrapStatusRepository.findById(orgId)
                    .orElseGet(() -> OrgBootstrapStatus.builder().orgId(orgId).build());
            status.setOnboardingCompleted(true);
            bootstrapStatusRepository.save(status);

            log.info("Bootstrapped QA test account: phone={} org='{}' ({}) with all {} modules enabled",
                    phone, orgName, orgId, ALL_MODULES.size());
        } catch (Exception e) {
            // Never let a QA-seed failure block startup.
            log.error("Test-account bootstrap failed for {}: {}", phone, e.getMessage(), e);
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }
}
