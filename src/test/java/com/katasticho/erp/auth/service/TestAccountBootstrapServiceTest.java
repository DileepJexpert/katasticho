package com.katasticho.erp.auth.service;

import com.katasticho.erp.auth.dto.AccountSubmissionResponse;
import com.katasticho.erp.auth.dto.RegisterRequest;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.entity.OrgBootstrapStatus;
import com.katasticho.erp.common.repository.OrgBootstrapStatusRepository;
import com.katasticho.erp.common.service.FeatureFlagService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Guards the QA-account seeder: it must be opt-in, idempotent, and — when it
 * does run — create the account through the real register path and flip on
 * every module so the test login sees the whole app.
 */
@ExtendWith(MockitoExtension.class)
class TestAccountBootstrapServiceTest {

    @Mock private AuthService authService;
    @Mock private AppUserRepository userRepository;
    @Mock private FeatureFlagService featureFlagService;
    @Mock private OrgBootstrapStatusRepository bootstrapStatusRepository;

    private TestAccountBootstrapService service;

    @BeforeEach
    void setUp() {
        service = new TestAccountBootstrapService(
                authService, userRepository, featureFlagService, bootstrapStatusRepository);
        set("enabled", true);
        set("phone", "9000000001");
        set("password", "Test@12345");
        set("fullName", "Test QA Owner");
        set("orgName", "Test QA Company");
        set("businessType", "DISTRIBUTOR");
        set("countryCode", "IN");
    }

    private void set(String field, Object value) {
        ReflectionTestUtils.setField(service, field, value);
    }

    @Test
    void disabled_doesNothing() {
        set("enabled", false);
        service.run(null);
        verifyNoInteractions(authService, userRepository, featureFlagService, bootstrapStatusRepository);
    }

    @Test
    void blankPassword_doesNotRegister() {
        set("password", "");
        service.run(null);
        verify(authService, never()).register(any());
    }

    @Test
    void alreadyExists_skipsRegister() {
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000001")).thenReturn(true);
        service.run(null);
        verify(authService, never()).register(any());
        verify(featureFlagService, never()).enable(any(), any());
    }

    @Test
    void happyPath_registersEnablesAllModulesAndCompletesOnboarding() {
        UUID orgId = UUID.randomUUID();
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000001")).thenReturn(false);
        when(authService.register(any(RegisterRequest.class)))
                .thenReturn(new AccountSubmissionResponse(orgId, UUID.randomUUID(),
                        "Test QA Company", "APPROVED", "ok"));
        when(bootstrapStatusRepository.findById(orgId)).thenReturn(Optional.empty());
        when(bootstrapStatusRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        service.run(null);

        // Registered through the real path with the configured creds.
        ArgumentCaptor<RegisterRequest> reqCap = ArgumentCaptor.forClass(RegisterRequest.class);
        verify(authService).register(reqCap.capture());
        RegisterRequest req = reqCap.getValue();
        assertEquals("9000000001", req.phone());
        assertEquals("Test@12345", req.password());
        assertEquals("DISTRIBUTOR", req.businessType());
        assertEquals("IN", req.countryCode());

        // Every module flag flipped on (24 module codes) for the new org.
        verify(featureFlagService, times(24)).enable(eq(orgId), any());
        verify(featureFlagService).enable(orgId, "MANUFACTURING");
        verify(featureFlagService).enable(orgId, "PAYROLL");
        verify(featureFlagService).enable(orgId, "SUPPLY_CHAIN");
        verify(featureFlagService).enable(orgId, "COURIER");

        // Onboarding marked done so the login lands straight in the app.
        ArgumentCaptor<OrgBootstrapStatus> statusCap = ArgumentCaptor.forClass(OrgBootstrapStatus.class);
        verify(bootstrapStatusRepository).save(statusCap.capture());
        assertTrue(statusCap.getValue().isOnboardingCompleted());
        assertEquals(orgId, statusCap.getValue().getOrgId());
    }

    @Test
    void registerFailure_isSwallowed() {
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000001")).thenReturn(false);
        when(authService.register(any())).thenThrow(new RuntimeException("boom"));
        // Must not propagate — a QA-seed failure can never block startup.
        assertDoesNotThrow(() -> service.run(null));
    }
}
