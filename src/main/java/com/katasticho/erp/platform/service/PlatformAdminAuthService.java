package com.katasticho.erp.platform.service;

import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.platform.entity.PlatformAdmin;
import com.katasticho.erp.platform.entity.PlatformAdminAudit;
import com.katasticho.erp.platform.repository.PlatformAdminAuditRepository;
import com.katasticho.erp.platform.repository.PlatformAdminRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PlatformAdminAuthService {

    private final PlatformAdminRepository platformAdminRepository;
    private final PlatformAdminAuditRepository auditRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    public record PlatformAdminAuthResponse(
            String accessToken,
            UUID adminId,
            String fullName,
            String role
    ) {}

    @Transactional
    public PlatformAdminAuthResponse login(String email, String password, String ipAddress) {
        PlatformAdmin admin = platformAdminRepository.findByEmail(email)
                .orElseThrow(() -> new BusinessException(
                        "Invalid credentials", "AUTH_BAD_CREDENTIALS", HttpStatus.UNAUTHORIZED));

        if (!admin.isActive()) {
            throw new BusinessException("Account is deactivated", "AUTH_ACCOUNT_INACTIVE", HttpStatus.FORBIDDEN);
        }

        if (admin.isLocked()) {
            throw new BusinessException(
                    "Account is locked. Try again later.",
                    "AUTH_ACCOUNT_LOCKED",
                    HttpStatus.TOO_MANY_REQUESTS);
        }

        if (!passwordEncoder.matches(password, admin.getPasswordHash())) {
            admin.incrementFailedLogins();
            if (admin.getFailedLoginCount() >= 5) {
                admin.lock(30);
                log.warn("Platform admin {} locked after 5 failed login attempts", admin.getId());
            }
            platformAdminRepository.save(admin);
            throw new BusinessException("Invalid credentials", "AUTH_BAD_CREDENTIALS", HttpStatus.UNAUTHORIZED);
        }

        admin.resetFailedLogins();
        admin.setLastLoginAt(Instant.now());
        platformAdminRepository.save(admin);

        String accessToken = jwtService.generatePlatformAdminToken(
                admin.getId(), admin.getRole(), admin.getTokenVersion());

        // Log audit
        PlatformAdminAudit audit = PlatformAdminAudit.builder()
                .platformAdminId(admin.getId())
                .actionType("LOGIN")
                .ipAddress(ipAddress)
                .build();
        auditRepository.save(audit);

        log.info("Platform admin logged in: {}", admin.getEmail());

        return new PlatformAdminAuthResponse(
                accessToken,
                admin.getId(),
                admin.getFullName(),
                admin.getRole()
        );
    }
}
