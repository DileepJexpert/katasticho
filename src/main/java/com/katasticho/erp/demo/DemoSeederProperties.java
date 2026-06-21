package com.katasticho.erp.demo;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

/**
 * Demo-mode configuration — gates the "log in without registering" path.
 *
 * <p>Default is OFF. Flip via env var (or {@code app.demo.enabled} property) only in
 * dev / staging / sandbox builds. The boot sequence ALSO requires {@code @Profile("!prod")}
 * on every seeder, so even an accidental {@code app.demo.enabled=true} on a prod profile
 * is inert.
 *
 * <h3>What demo mode does</h3>
 * <ol>
 *   <li>{@link DemoOrgBootstrap} — creates a demo Organisation + OWNER user the first time the
 *       app boots (idempotent on subsequent boots) via the existing {@code AuthService.register}
 *       path, so the org gets the same CoA / branch / warehouse a real signup gets.</li>
 *   <li>{@link DevUserSeeder} — adds the other demo users (one per role) inside that org,
 *       password-hashed with the live {@link org.springframework.security.crypto.password.PasswordEncoder}.</li>
 *   <li>{@code GET /api/v1/auth/demo-info} — surfaces the credentials on the Flutter login screen
 *       so the demo-er doesn't have to dig them out of a doc.</li>
 * </ol>
 *
 * <h3>Why a property + profile instead of just one</h3>
 * Two layers prevents a prod build from EVER seeding demo data, even with a misconfigured env.
 * The hospital-os repo uses the same belt-and-braces pattern ({@code @Profile("!prod")} +
 * {@code katixo.tenant.demo.enabled}).
 */
@ConfigurationProperties(prefix = "app.demo")
public record DemoSeederProperties(
        /**
         * Master switch — when false (the default), every seeder + the {@code /demo-info}
         * endpoint short-circuit to a no-op.
         */
        boolean enabled,
        /** Org name created by {@link DemoOrgBootstrap}. */
        String orgName,
        /** Business type stamped on the demo org (drives industry-specific defaults). */
        String businessType,
        /** Industry code stamped on the demo org. */
        String industryCode,
        /** Owner phone — also the login identifier for the demo OWNER user. */
        String ownerPhone,
        /** Shared password for every demo user. ≥ 8 chars to satisfy {@code @Size} on register. */
        String sharedPassword
) {
    public DemoSeederProperties {
        if (orgName == null || orgName.isBlank()) orgName = "Demo Distributor";
        if (businessType == null || businessType.isBlank()) businessType = "DISTRIBUTOR";
        if (industryCode == null || industryCode.isBlank()) industryCode = "OTHER_RETAIL";
        if (ownerPhone == null || ownerPhone.isBlank()) ownerPhone = "9000000001";
        if (sharedPassword == null || sharedPassword.isBlank()) sharedPassword = "Demo@1234";
    }

    /**
     * The 8 demo logins seeded into the demo org. Order matters for {@link DemoUserSpec#OWNER_INDEX}
     * — the OWNER spec is consumed by {@link DemoOrgBootstrap} (via {@code register}) and is
     * skipped by {@link DevUserSeeder} (it'd already exist).
     *
     * <p>Roles use the exact values from {@code AppUser.role} +
     * {@code @PreAuthorize("hasRole(...)")} — OWNER, ADMIN, ACCOUNTANT, OPERATOR, VIEWER.
     * Multiple demo users can share a role (e.g. {@code cashier} + {@code salesman} are both
     * OPERATOR) because the role enum is intentionally narrow and the use-case is broader.
     */
    public List<DemoUserSpec> users() {
        return List.of(
                new DemoUserSpec(ownerPhone, "Demo Owner", "OWNER"),
                new DemoUserSpec("9000000002", "Demo Admin", "ADMIN"),
                new DemoUserSpec("9000000003", "Demo Accountant", "ACCOUNTANT"),
                new DemoUserSpec("9000000004", "Demo Cashier", "OPERATOR"),
                new DemoUserSpec("9000000005", "Demo Salesman", "OPERATOR"),
                new DemoUserSpec("9000000006", "Demo Manager", "ADMIN"),
                new DemoUserSpec("9000000007", "Demo Viewer", "VIEWER"),
                new DemoUserSpec("9000000008", "Demo Operator", "OPERATOR"));
    }

    /** {@link #users()} index of the OWNER — {@link DemoOrgBootstrap}'s anchor. */
    public static final int OWNER_INDEX = 0;

    public record DemoUserSpec(String phone, String fullName, String role) {}
}
