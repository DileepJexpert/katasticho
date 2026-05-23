package com.katasticho.erp.auth.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.entity.PasswordResetToken;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.auth.repository.PasswordResetTokenRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.notification.EmailService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PasswordResetService {

    private final AppUserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;

    /**
     * Initiates an email-based password reset.
     * Always returns without revealing whether the identifier is registered.
     */
    @Transactional
    public void initiateReset(String identifier) {
        if (identifier == null || identifier.isBlank()) {
            return;
        }

        // Try to find user by email first, then by phone
        List<AppUser> users = userRepository.findAllByEmailAndIsDeletedFalse(identifier);
        if (users.isEmpty()) {
            users = userRepository.findAllByPhoneAndIsDeletedFalse(identifier);
        }

        if (users.isEmpty()) {
            // Silent return — never reveal if identifier exists
            log.debug("Password reset requested for unknown identifier: {}", identifier);
            return;
        }

        // Pick the most recently active user
        AppUser user = users.stream()
                .filter(AppUser::isActive)
                .max(java.util.Comparator.comparing(
                        u -> u.getLastLoginAt() != null ? u.getLastLoginAt() : Instant.EPOCH))
                .orElse(null);

        if (user == null || user.getEmail() == null) {
            log.debug("Password reset requested but user has no email or is inactive: {}", identifier);
            return;
        }

        // Invalidate any existing tokens for this user
        tokenRepository.invalidateAllForUser(user.getId(), Instant.now());

        // Generate a new token
        String rawToken = UUID.randomUUID().toString().replace("-", "");
        String tokenHash = sha256Hex(rawToken);

        PasswordResetToken resetToken = PasswordResetToken.builder()
                .userId(user.getId())
                .tokenHash(tokenHash)
                .deliveryMethod("EMAIL")
                .deliveredTo(user.getEmail())
                .expiresAt(Instant.now().plusSeconds(30 * 60)) // 30 minutes
                .build();
        tokenRepository.save(resetToken);

        emailService.sendPasswordReset(user.getEmail(), user.getFullName(), rawToken);
        log.info("Password reset email sent to user: {}", user.getId());
    }

    /**
     * Completes the email-based password reset using the raw token.
     */
    @Transactional
    public void resetPassword(String rawToken, String newPassword) {
        validatePasswordStrength(newPassword);

        String tokenHash = sha256Hex(rawToken);

        PasswordResetToken resetToken = tokenRepository
                .findByTokenHashAndUsedFalseAndExpiresAtAfter(tokenHash, Instant.now())
                .orElseThrow(() -> new BusinessException(
                        "Invalid or expired password reset token",
                        "AUTH_INVALID_RESET_TOKEN",
                        HttpStatus.BAD_REQUEST));

        AppUser user = userRepository.findById(resetToken.getUserId())
                .filter(u -> !u.isDeleted())
                .orElseThrow(() -> new BusinessException(
                        "User not found",
                        "AUTH_USER_NOT_FOUND",
                        HttpStatus.NOT_FOUND));

        // Mark token as used
        resetToken.markUsed();
        tokenRepository.save(resetToken);

        // Update password and increment tokenVersion (invalidates all existing sessions)
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.resetFailedLogins();
        user.incrementTokenVersion();
        userRepository.save(user);

        log.info("Password reset completed for user: {}", user.getId());
    }

    private void validatePasswordStrength(String password) {
        if (password == null || password.length() < 8) {
            throw new BusinessException(
                    "Password must be at least 8 characters long",
                    "AUTH_WEAK_PASSWORD",
                    HttpStatus.BAD_REQUEST);
        }
        if (!password.matches(".*[A-Z].*")) {
            throw new BusinessException(
                    "Password must contain at least one uppercase letter",
                    "AUTH_WEAK_PASSWORD",
                    HttpStatus.BAD_REQUEST);
        }
        if (!password.matches(".*[a-z].*")) {
            throw new BusinessException(
                    "Password must contain at least one lowercase letter",
                    "AUTH_WEAK_PASSWORD",
                    HttpStatus.BAD_REQUEST);
        }
        if (!password.matches(".*\\d.*")) {
            throw new BusinessException(
                    "Password must contain at least one digit",
                    "AUTH_WEAK_PASSWORD",
                    HttpStatus.BAD_REQUEST);
        }
        if (!password.matches(".*[@#$%^&*!].*")) {
            throw new BusinessException(
                    "Password must contain at least one special character (@#$%^&*!)",
                    "AUTH_WEAK_PASSWORD",
                    HttpStatus.BAD_REQUEST);
        }
    }

    private String sha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }
}
