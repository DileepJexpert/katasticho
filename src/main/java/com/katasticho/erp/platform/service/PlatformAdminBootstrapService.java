package com.katasticho.erp.platform.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class PlatformAdminBootstrapService {

    private final OrganisationRepository organisationRepository;
    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.platform-admin.phone:}")
    private String adminPhone;

    @Value("${app.platform-admin.email:}")
    private String adminEmail;

    @Value("${app.platform-admin.password:}")
    private String adminPassword;

    @PostConstruct
    @Transactional
    public void bootstrap() {
        if (isBlank(adminPassword) || (isBlank(adminPhone) && isBlank(adminEmail))) {
            return;
        }

        List<AppUser> existing = !isBlank(adminPhone)
                ? userRepository.findAllByPhoneAndIsDeletedFalse(adminPhone)
                : userRepository.findAllByEmailAndIsDeletedFalse(adminEmail);
        boolean alreadyExists = existing.stream().anyMatch(u -> "PLATFORM_ADMIN".equals(u.getRole()));
        if (alreadyExists) {
            return;
        }

        Organisation org = Organisation.builder()
                .name("Katixo Platform")
                .businessType("SERVICE_PROVIDER")
                .industryCode("OTHER_RETAIL")
                .approvalStatus("APPROVED")
                .approvedAt(Instant.now())
                .subCategories(List.of())
                .build();
        org = organisationRepository.save(org);

        AppUser admin = AppUser.builder()
                .fullName("Katixo Platform Admin")
                .phone(isBlank(adminPhone) ? null : adminPhone)
                .email(isBlank(adminEmail) ? null : adminEmail)
                .passwordHash(passwordEncoder.encode(adminPassword))
                .role("PLATFORM_ADMIN")
                .defaultLandingPage("/platform-admin")
                .build();
        admin.setOrgId(org.getId());
        userRepository.save(admin);
        log.info("Bootstrapped PLATFORM_ADMIN account for Katixo Platform");
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }
}
