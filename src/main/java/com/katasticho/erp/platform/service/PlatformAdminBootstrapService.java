package com.katasticho.erp.platform.service;

import com.katasticho.erp.platform.entity.PlatformAdmin;
import com.katasticho.erp.platform.repository.PlatformAdminRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class PlatformAdminBootstrapService {

    private final PlatformAdminRepository platformAdminRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.platform-admin.email:}")
    private String adminEmail;

    @Value("${app.platform-admin.password:}")
    private String adminPassword;

    @PostConstruct
    @Transactional
    public void bootstrap() {
        if (isBlank(adminPassword) || isBlank(adminEmail)) {
            log.info("Platform admin bootstrap skipped — PLATFORM_ADMIN_EMAIL or PLATFORM_ADMIN_PASSWORD not set");
            return;
        }

        boolean alreadyExists = platformAdminRepository.findByEmail(adminEmail).isPresent();
        if (alreadyExists) {
            return;
        }

        PlatformAdmin admin = PlatformAdmin.builder()
                .fullName("Katixo Platform Admin")
                .email(adminEmail)
                .passwordHash(passwordEncoder.encode(adminPassword))
                .role("PLATFORM_ADMIN")
                .build();
        platformAdminRepository.save(admin);
        log.info("Bootstrapped PLATFORM_ADMIN account in platform_admin table for: {}", adminEmail);
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }
}
