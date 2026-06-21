package com.katasticho.erp.demo;

import com.katasticho.erp.auth.dto.RegisterRequest;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.auth.service.AuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DemoOrgBootstrapTest {

    @Mock private AppUserRepository userRepository;
    @Mock private AuthService authService;
    private DemoSeederProperties props;
    private DemoOrgBootstrap bootstrap;

    @BeforeEach
    void setUp() {
        // Defaults defined inside DemoSeederProperties' canonical constructor —
        // pass nulls to exercise the fallbacks and lock the public contract.
        props = new DemoSeederProperties(true, null, null, null, null, null);
        bootstrap = new DemoOrgBootstrap(props, userRepository, authService);
    }

    @Test
    void registers_demo_org_when_owner_phone_is_not_yet_taken() {
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000001")).thenReturn(false);

        bootstrap.run();

        ArgumentCaptor<RegisterRequest> captor = ArgumentCaptor.forClass(RegisterRequest.class);
        verify(authService).register(captor.capture());
        RegisterRequest req = captor.getValue();
        assertEquals("9000000001", req.phone());
        assertEquals("Demo@1234", req.password());
        assertEquals("Demo Owner", req.fullName());
        assertEquals("Demo Distributor", req.orgName());
        assertEquals("DISTRIBUTOR", req.businessType());
    }

    @Test
    void skips_when_owner_phone_already_present_so_a_second_boot_is_a_noop() {
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000001")).thenReturn(true);

        bootstrap.run();

        verify(authService, never()).register(any());
    }
}
