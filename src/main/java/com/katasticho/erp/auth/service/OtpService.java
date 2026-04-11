package com.katasticho.erp.auth.service;

import com.katasticho.erp.common.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;

@Service
@Slf4j
public class OtpService {

    private static final String OTP_PREFIX = "otp:";
    private static final String OTP_ATTEMPTS_PREFIX = "otp_attempts:";
    private static final String OTP_LOCK_PREFIX = "otp_lock:";

    private final StringRedisTemplate redisTemplate;
    private final int expiryMinutes;
    private final int maxAttempts;
    private final int lockoutMinutes;
    private final SecureRandom secureRandom = new SecureRandom();

    public OtpService(
            StringRedisTemplate redisTemplate,
            @Value("${app.otp.expiry-minutes}") int expiryMinutes,
            @Value("${app.otp.max-attempts}") int maxAttempts,
            @Value("${app.otp.lockout-minutes}") int lockoutMinutes
    ) {
        this.redisTemplate = redisTemplate;
        this.expiryMinutes = expiryMinutes;
        this.maxAttempts = maxAttempts;
        this.lockoutMinutes = lockoutMinutes;
    }

    public String generateAndStore(String phone) {
        // Check if locked
        String lockKey = OTP_LOCK_PREFIX + phone;
        if (Boolean.TRUE.equals(redisTemplate.hasKey(lockKey))) {
            throw new BusinessException(
                    "Too many failed attempts. Account locked for " + lockoutMinutes + " minutes.",
                    "AUTH_ACCOUNT_LOCKED",
                    HttpStatus.TOO_MANY_REQUESTS
            );
        }

        // Generate 6-digit OTP
        String otp = String.format("%06d", secureRandom.nextInt(1_000_000));

        // Store in Redis with TTL
        String otpKey = OTP_PREFIX + phone;
        redisTemplate.opsForValue().set(otpKey, otp, Duration.ofMinutes(expiryMinutes));

        // Reset attempt counter on new OTP
        String attemptsKey = OTP_ATTEMPTS_PREFIX + phone;
        redisTemplate.delete(attemptsKey);

        log.info("OTP generated for phone: {}***{}", phone.substring(0, 3), phone.substring(phone.length() - 2));
        // In production: send via MSG91. For dev, log it.
        log.debug("DEV OTP for {}: {}", phone, otp);

        return otp;
    }

    public boolean verify(String phone, String otp) {
        // Check if locked
        String lockKey = OTP_LOCK_PREFIX + phone;
        if (Boolean.TRUE.equals(redisTemplate.hasKey(lockKey))) {
            throw new BusinessException(
                    "Too many failed attempts. Account locked for " + lockoutMinutes + " minutes.",
                    "AUTH_ACCOUNT_LOCKED",
                    HttpStatus.TOO_MANY_REQUESTS
            );
        }

        String otpKey = OTP_PREFIX + phone;
        String storedOtp = redisTemplate.opsForValue().get(otpKey);

        if (storedOtp == null) {
            incrementFailedAttempts(phone);
            return false;
        }

        if (!storedOtp.equals(otp)) {
            incrementFailedAttempts(phone);
            return false;
        }

        // OTP matches — clean up
        redisTemplate.delete(otpKey);
        redisTemplate.delete(OTP_ATTEMPTS_PREFIX + phone);
        return true;
    }

    private void incrementFailedAttempts(String phone) {
        String attemptsKey = OTP_ATTEMPTS_PREFIX + phone;
        Long attempts = redisTemplate.opsForValue().increment(attemptsKey);
        redisTemplate.expire(attemptsKey, Duration.ofMinutes(expiryMinutes));

        if (attempts != null && attempts >= maxAttempts) {
            // Lock the phone number
            String lockKey = OTP_LOCK_PREFIX + phone;
            redisTemplate.opsForValue().set(lockKey, "locked", Duration.ofMinutes(lockoutMinutes));
            redisTemplate.delete(OTP_PREFIX + phone);
            redisTemplate.delete(attemptsKey);
            log.warn("Phone {} locked after {} failed OTP attempts", phone, maxAttempts);
        }
    }
}
