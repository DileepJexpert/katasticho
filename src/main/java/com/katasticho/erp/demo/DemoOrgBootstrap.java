package com.katasticho.erp.demo;

import com.katasticho.erp.auth.dto.RegisterRequest;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.auth.service.AuthService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.util.Collections;

/**
 * Provisions the demo organisation on first boot — same code path a real signup
 * goes through, so the demo org gets the same default branch + warehouse + chart
 * of accounts (61 ledgers) + UoM + GST tax config any other org gets.
 *
 * <p>Idempotent: the second boot finds the OWNER phone already registered and
 * exits without touching anything. Manual deletion (or a {@link DemoResetService}-
 * style wipe — wired in a follow-up commit) re-arms the bootstrap.
 *
 * <p>Two-layer safety:
 * <ul>
 *   <li>{@code @Profile("!prod")} — never runs on the prod profile, full stop.</li>
 *   <li>{@code @ConditionalOnProperty("app.demo.enabled")} — also off by default
 *       on every other profile until an operator flips it.</li>
 * </ul>
 *
 * <p>{@code @Order(1)} pins this BEFORE {@link DevUserSeeder} (@Order(2)) — the
 * other 7 demo users can't be created until the org exists.
 */
@Component
@Profile("!prod")
@ConditionalOnProperty(prefix = "app.demo", name = "enabled", havingValue = "true")
@EnableConfigurationProperties(DemoSeederProperties.class)
@RequiredArgsConstructor
@Order(1)
@Slf4j
public class DemoOrgBootstrap implements CommandLineRunner {

    private final DemoSeederProperties props;
    private final AppUserRepository userRepository;
    private final AuthService authService;

    @Override
    public void run(String... args) {
        if (userRepository.existsByPhoneAndIsDeletedFalse(props.ownerPhone())) {
            log.info("[demo] org already provisioned for owner phone {} — skipping bootstrap",
                    props.ownerPhone());
            return;
        }

        log.info("[demo] provisioning '{}' (owner phone {})", props.orgName(), props.ownerPhone());

        DemoSeederProperties.DemoUserSpec owner =
                props.users().get(DemoSeederProperties.OWNER_INDEX);
        RegisterRequest req = new RegisterRequest(
                owner.phone(),
                props.sharedPassword(),
                owner.fullName(),
                props.orgName(),
                props.businessType(),
                props.industryCode(),
                Collections.emptyList());

        // register() saves org + branch + warehouse, hashes the password, creates
        // the OWNER user, and registers an after-commit hook that bootstraps the
        // chart of accounts / UoM / GST tax config. One call, full setup.
        authService.register(req);

        log.info("[demo] '{}' provisioned. Login: {} / {} (role OWNER)",
                props.orgName(), owner.phone(), props.sharedPassword());
    }
}
