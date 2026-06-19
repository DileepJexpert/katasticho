package com.katasticho.erp.portal.service;

import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.portal.entity.PortalUser;
import com.katasticho.erp.portal.repository.PortalUserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PortalAuthServiceTest {

    @Mock private PortalUserRepository portalUserRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private JwtService jwtService;
    private PortalAuthService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new PortalAuthService(portalUserRepository, contactRepository, passwordEncoder, jwtService);
        TenantContext.setCurrentOrgId(orgId);
        when(jwtService.hashToken(any())).thenAnswer(i -> "hash:" + i.getArgument(0));
        when(portalUserRepository.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Contact customer() {
        return Contact.builder()
                .displayName("Acme Retail").email("buyer@acme.test")
                .contactType(ContactType.CUSTOMER).build();
    }

    @Test
    void invite_createsInvitedAccountWithOneTimeToken() {
        Contact c = customer();
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)).thenReturn(Optional.of(c));
        when(portalUserRepository.findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId))
                .thenReturn(Optional.empty());
        when(portalUserRepository.existsByEmailIgnoreCaseAndIsDeletedFalse(any())).thenReturn(false);

        Map<String, Object> r = service.invite(contactId, null, null);

        assertEquals("INVITED", r.get("status"));
        assertEquals("CUSTOMER", r.get("kind"));
        assertEquals("buyer@acme.test", r.get("email"));
        assertNotNull(r.get("inviteToken"));
        assertTrue(r.get("inviteToken").toString().startsWith("cpt_"));
    }

    @Test
    void invite_duplicateContact_throws() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(customer()));
        when(portalUserRepository.findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId))
                .thenReturn(Optional.of(PortalUser.builder().build()));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.invite(contactId, null, null));
        assertEquals("PORTAL_ALREADY_INVITED", ex.getErrorCode());
    }

    @Test
    void acceptInvite_setsPasswordActivatesAndReturnsSession() {
        PortalUser pu = PortalUser.builder()
                .id(UUID.randomUUID()).orgId(orgId).contactId(contactId).kind("CUSTOMER")
                .email("buyer@acme.test").status("INVITED")
                .inviteTokenHash("hash:cpt_raw")
                .inviteExpiresAt(Instant.now().plus(1, ChronoUnit.DAYS)).build();
        when(portalUserRepository.findByInviteTokenHashAndIsDeletedFalse("hash:cpt_raw"))
                .thenReturn(Optional.of(pu));
        when(passwordEncoder.encode("secret123")).thenReturn("enc");
        when(jwtService.generatePortalToken(any(), any(), any(), any(), anyIntArg(), anyLongArg()))
                .thenReturn("portal.jwt");

        Map<String, Object> r = service.acceptInvite("cpt_raw", "secret123");

        assertEquals("portal.jwt", r.get("token"));
        assertEquals("ACTIVE", pu.getStatus());
        assertEquals("enc", pu.getPasswordHash());
        assertNull(pu.getInviteTokenHash());
    }

    @Test
    void acceptInvite_expired_throws() {
        PortalUser pu = PortalUser.builder()
                .id(UUID.randomUUID()).orgId(orgId).status("INVITED")
                .inviteTokenHash("hash:cpt_raw")
                .inviteExpiresAt(Instant.now().minus(1, ChronoUnit.DAYS)).build();
        when(portalUserRepository.findByInviteTokenHashAndIsDeletedFalse("hash:cpt_raw"))
                .thenReturn(Optional.of(pu));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.acceptInvite("cpt_raw", "secret123"));
        assertEquals("PORTAL_INVITE_EXPIRED", ex.getErrorCode());
    }

    @Test
    void login_activeUserCorrectPassword_returnsSession() {
        PortalUser pu = PortalUser.builder()
                .id(UUID.randomUUID()).orgId(orgId).contactId(contactId).kind("CUSTOMER")
                .email("buyer@acme.test").status("ACTIVE").passwordHash("enc").build();
        when(portalUserRepository.findByEmailIgnoreCaseAndIsDeletedFalse("buyer@acme.test"))
                .thenReturn(Optional.of(pu));
        when(passwordEncoder.matches("secret123", "enc")).thenReturn(true);
        when(jwtService.generatePortalToken(any(), any(), any(), any(), anyIntArg(), anyLongArg()))
                .thenReturn("portal.jwt");

        Map<String, Object> r = service.login("Buyer@Acme.test", "secret123");
        assertEquals("portal.jwt", r.get("token"));
    }

    @Test
    void login_wrongPassword_throws() {
        PortalUser pu = PortalUser.builder()
                .id(UUID.randomUUID()).status("ACTIVE").passwordHash("enc").build();
        when(portalUserRepository.findByEmailIgnoreCaseAndIsDeletedFalse("buyer@acme.test"))
                .thenReturn(Optional.of(pu));
        when(passwordEncoder.matches(any(), any())).thenReturn(false);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.login("buyer@acme.test", "wrong"));
        assertEquals("PORTAL_BAD_CREDENTIALS", ex.getErrorCode());
    }

    @Test
    void login_suspended_throws() {
        PortalUser pu = PortalUser.builder()
                .id(UUID.randomUUID()).status("SUSPENDED").passwordHash("enc").build();
        when(portalUserRepository.findByEmailIgnoreCaseAndIsDeletedFalse("buyer@acme.test"))
                .thenReturn(Optional.of(pu));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.login("buyer@acme.test", "secret123"));
        assertEquals("PORTAL_NOT_ACTIVE", ex.getErrorCode());
    }

    private static int anyIntArg() {
        return org.mockito.ArgumentMatchers.anyInt();
    }

    private static long anyLongArg() {
        return org.mockito.ArgumentMatchers.anyLong();
    }
}
