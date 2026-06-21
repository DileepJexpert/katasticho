package com.katasticho.erp.demo;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Adds the other 7 demo-user logins (admin / accountant / cashier / salesman /
 * manager / viewer / operator) into the demo org that {@link DemoOrgBootstrap}
 * just provisioned. The OWNER is skipped here — it's already there.
 *
 * <p>Each demo user is bcrypt-hashed with the live {@link PasswordEncoder}, so
 * demo and prod use byte-for-byte identical hash format. A future encoder swap
 * (argon2, scrypt) requires no change here.
 *
 * <p>{@code @Order(2)} pins this AFTER {@link DemoOrgBootstrap} (@Order(1)) so
 * the owner row + org row already exist when we look them up.
 *
 * <p>Idempotent: every user phone is checked before insert. Reruns skip
 * existing rows silently.
 */
@Component
@Profile("!prod")
@ConditionalOnProperty(prefix = "app.demo", name = "enabled", havingValue = "true")
@EnableConfigurationProperties(DemoSeederProperties.class)
@RequiredArgsConstructor
@Order(2)
@Slf4j
public class DevUserSeeder implements CommandLineRunner {

    private final DemoSeederProperties props;
    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbcTemplate;

    @Override
    @Transactional
    public void run(String... args) {
        // Find the demo org via its OWNER phone — set up by DemoOrgBootstrap.
        AppUser owner = userRepository.findAllByPhoneAndIsDeletedFalse(props.ownerPhone())
                .stream().findFirst().orElse(null);
        if (owner == null || owner.getOrgId() == null) {
            log.warn("[demo] owner user not found (phone {}) — bootstrap may have failed; skipping user seeding",
                    props.ownerPhone());
            return;
        }
        UUID orgId = owner.getOrgId();

        // Locate the demo org's default branch so each new user gets stamped with
        // the same branch_id register() set on the owner — list screens that
        // filter on branch otherwise show empty.
        UUID defaultBranchId = jdbcTemplate.query(
                "SELECT id FROM branch WHERE org_id = ? AND is_default = TRUE LIMIT 1",
                (rs, n) -> (UUID) rs.getObject(1),
                orgId).stream().findFirst().orElse(null);

        String hash = passwordEncoder.encode(props.sharedPassword());

        List<DemoSeederProperties.DemoUserSpec> specs = props.users();
        int created = 0;
        int skipped = 0;
        // Skip index 0 — that's the OWNER, already in the DB.
        for (int i = 1; i < specs.size(); i++) {
            DemoSeederProperties.DemoUserSpec spec = specs.get(i);
            if (userRepository.existsByPhoneAndIsDeletedFalse(spec.phone())) {
                skipped++;
                continue;
            }
            AppUser user = AppUser.builder()
                    .phone(spec.phone())
                    .fullName(spec.fullName())
                    .passwordHash(hash)
                    .role(spec.role())
                    .build();
            user.setOrgId(orgId);
            user.setLastLoginAt(Instant.now());
            user = userRepository.saveAndFlush(user);
            if (defaultBranchId != null) {
                jdbcTemplate.update(
                        "UPDATE app_user SET branch_id = ? WHERE id = ?",
                        defaultBranchId, user.getId());
            }
            created++;
        }

        log.info("[demo] users seeded: {} created, {} already present. All passwords: {}",
                created, skipped, props.sharedPassword());
    }
}
