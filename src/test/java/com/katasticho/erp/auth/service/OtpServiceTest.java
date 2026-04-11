package com.katasticho.erp.auth.service;

import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OtpServiceTest {

    @Mock
    private StringRedisTemplate redisTemplate;
    @Mock
    private ValueOperations<String, String> valueOps;

    private OtpService otpService;

    @BeforeEach
    void setUp() {
        lenient().when(redisTemplate.opsForValue()).thenReturn(valueOps);
        otpService = new OtpService(redisTemplate, 5, 5, 30);
    }

    @Test
    void shouldGenerateAndStoreOtp() {
        when(redisTemplate.hasKey("otp_lock:+919876543210")).thenReturn(false);

        String otp = otpService.generateAndStore("+919876543210");

        assertNotNull(otp);
        assertEquals(6, otp.length());
        assertTrue(otp.matches("\\d{6}"));

        verify(valueOps).set(eq("otp:+919876543210"), eq(otp), eq(Duration.ofMinutes(5)));
    }

    @Test
    void shouldVerifyCorrectOtp() {
        when(redisTemplate.hasKey("otp_lock:+919876543210")).thenReturn(false);
        when(valueOps.get("otp:+919876543210")).thenReturn("123456");

        boolean result = otpService.verify("+919876543210", "123456");

        assertTrue(result);
        verify(redisTemplate).delete("otp:+919876543210");
    }

    @Test
    void shouldRejectWrongOtp() {
        when(redisTemplate.hasKey("otp_lock:+919876543210")).thenReturn(false);
        when(valueOps.get("otp:+919876543210")).thenReturn("123456");
        when(valueOps.increment("otp_attempts:+919876543210")).thenReturn(1L);

        boolean result = otpService.verify("+919876543210", "000000");

        assertFalse(result);
    }

    @Test
    void shouldRejectExpiredOtp() {
        when(redisTemplate.hasKey("otp_lock:+919876543210")).thenReturn(false);
        when(valueOps.get("otp:+919876543210")).thenReturn(null);
        when(valueOps.increment("otp_attempts:+919876543210")).thenReturn(1L);

        boolean result = otpService.verify("+919876543210", "123456");

        assertFalse(result);
    }

    @Test
    void shouldLockAfter5FailedAttempts() {
        when(redisTemplate.hasKey("otp_lock:+919876543210")).thenReturn(false);
        when(valueOps.get("otp:+919876543210")).thenReturn("123456");
        when(valueOps.increment("otp_attempts:+919876543210")).thenReturn(5L);

        boolean result = otpService.verify("+919876543210", "000000");

        assertFalse(result);
        // Verify lock was set
        verify(valueOps).set(eq("otp_lock:+919876543210"), eq("locked"), eq(Duration.ofMinutes(30)));
    }

    @Test
    void shouldRejectOtpWhenLocked() {
        when(redisTemplate.hasKey("otp_lock:+919876543210")).thenReturn(true);

        assertThrows(BusinessException.class, () -> otpService.verify("+919876543210", "123456"));
    }

    @Test
    void shouldRejectOtpRequestWhenLocked() {
        when(redisTemplate.hasKey("otp_lock:+919876543210")).thenReturn(true);

        assertThrows(BusinessException.class, () -> otpService.generateAndStore("+919876543210"));
    }
}
