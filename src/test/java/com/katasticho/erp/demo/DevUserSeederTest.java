package com.katasticho.erp.demo;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DevUserSeederTest {

    @Mock private AppUserRepository userRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private JdbcTemplate jdbcTemplate;
    private DemoSeederProperties props;
    private DevUserSeeder seeder;

    private final UUID orgId = UUID.randomUUID();
    private final UUID branchId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        props = new DemoSeederProperties(true, null, null, null, null, null);
        seeder = new DevUserSeeder(props, userRepository, passwordEncoder, jdbcTemplate);
    }

    @SuppressWarnings("unchecked")
    private void stubOwnerLookup() {
        AppUser owner = AppUser.builder().phone("9000000001").role("OWNER").build();
        owner.setOrgId(orgId);
        when(userRepository.findAllByPhoneAndIsDeletedFalse("9000000001")).thenReturn(List.of(owner));
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), eq(orgId)))
                .thenReturn(List.of(branchId));
    }

    @Test
    void skips_when_owner_user_is_missing_so_a_failed_bootstrap_does_not_cascade() {
        when(userRepository.findAllByPhoneAndIsDeletedFalse("9000000001")).thenReturn(List.of());

        seeder.run();

        verify(userRepository, never()).saveAndFlush(any(AppUser.class));
        verifyNoInteractions(passwordEncoder);
    }

    @Test
    void seeds_all_seven_non_owner_users_with_bcrypt_hash_and_correct_roles() {
        stubOwnerLookup();
        when(userRepository.existsByPhoneAndIsDeletedFalse(anyString())).thenReturn(false);
        when(passwordEncoder.encode("Demo@1234")).thenReturn("bcrypt-hash");
        when(userRepository.saveAndFlush(any(AppUser.class)))
                .thenAnswer(inv -> {
                    AppUser u = inv.getArgument(0);
                    u.setId(UUID.randomUUID()); // simulate save
                    return u;
                });

        seeder.run();

        ArgumentCaptor<AppUser> captor = ArgumentCaptor.forClass(AppUser.class);
        verify(userRepository, times(7)).saveAndFlush(captor.capture());

        List<AppUser> saved = captor.getAllValues();
        // Phones — owner (9000000001) skipped, the rest in order.
        assertEquals("9000000002", saved.get(0).getPhone());
        assertEquals("9000000008", saved.get(6).getPhone());
        // All carry the demo org + bcrypt hash + branch update fires.
        for (AppUser u : saved) {
            assertEquals(orgId, u.getOrgId());
            assertEquals("bcrypt-hash", u.getPasswordHash());
            assertNotNull(u.getLastLoginAt());
        }
        // Role distribution mirrors the spec exactly.
        assertEquals("ADMIN", saved.get(0).getRole());      // admin
        assertEquals("ACCOUNTANT", saved.get(1).getRole()); // accountant
        assertEquals("OPERATOR", saved.get(2).getRole());   // cashier
        assertEquals("OPERATOR", saved.get(3).getRole());   // salesman
        assertEquals("ADMIN", saved.get(4).getRole());      // manager
        assertEquals("VIEWER", saved.get(5).getRole());     // viewer
        assertEquals("OPERATOR", saved.get(6).getRole());   // operator
        // Each new user gets the branch update so list screens find them.
        verify(jdbcTemplate, times(7))
                .update(eq("UPDATE app_user SET branch_id = ? WHERE id = ?"), eq(branchId), any(UUID.class));
    }

    @Test
    void second_run_skips_already_present_users_so_reboot_is_idempotent() {
        stubOwnerLookup();
        // Pretend 3 of the 7 demo users are already in the DB; the seeder should
        // create only the missing 4 and never re-hash for the others.
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000002")).thenReturn(true);
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000003")).thenReturn(true);
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000004")).thenReturn(true);
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000005")).thenReturn(false);
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000006")).thenReturn(false);
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000007")).thenReturn(false);
        when(userRepository.existsByPhoneAndIsDeletedFalse("9000000008")).thenReturn(false);
        when(passwordEncoder.encode("Demo@1234")).thenReturn("bcrypt-hash");
        when(userRepository.saveAndFlush(any(AppUser.class)))
                .thenAnswer(inv -> {
                    AppUser u = inv.getArgument(0);
                    u.setId(UUID.randomUUID());
                    return u;
                });

        seeder.run();

        verify(userRepository, times(4)).saveAndFlush(any(AppUser.class));
    }
}
