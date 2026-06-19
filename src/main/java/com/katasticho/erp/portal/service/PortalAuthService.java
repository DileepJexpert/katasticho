package com.katasticho.erp.portal.service;

import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.portal.entity.PortalUser;
import com.katasticho.erp.portal.repository.PortalUserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Self-service portal accounts for external customers/vendors.
 *
 * <p>Lifecycle: an admin <b>invites</b> a Contact (creates an INVITED account +
 * a one-time invite token shared with the contact) → the contact <b>accepts</b>
 * the invite and sets a password (→ ACTIVE) → they <b>log in</b> with
 * email+password and receive a portal JWT (signed with the isolated portal key).
 * Admins may suspend/reactivate/resend. Portal accounts are entirely separate
 * from the app's {@code AppUser}s.
 */
@Service
@RequiredArgsConstructor
public class PortalAuthService {

    private static final String INVITE_PREFIX = "cpt_";
    private static final int INVITE_TTL_DAYS = 7;
    private static final long PORTAL_TOKEN_MINUTES = 12 * 60; // 12h session

    private final PortalUserRepository portalUserRepository;
    private final ContactRepository contactRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final SecureRandom secureRandom = new SecureRandom();

    // ── Admin: invite / manage ───────────────────────────────────────────

    /** Invite a contact to the portal. Returns the account + a one-time invite token. */
    @Transactional
    public Map<String, Object> invite(UUID contactId, String email, String fullName) {
        UUID orgId = requireOrgId();
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));

        String normEmail = normEmail(email != null && !email.isBlank() ? email : contact.getEmail());
        if (normEmail == null) {
            throw new BusinessException("An email is required to invite this contact",
                    "PORTAL_EMAIL_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (portalUserRepository.findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId).isPresent()) {
            throw new BusinessException("This contact already has a portal account",
                    "PORTAL_ALREADY_INVITED", HttpStatus.CONFLICT);
        }
        if (portalUserRepository.existsByEmailIgnoreCaseAndIsDeletedFalse(normEmail)) {
            throw new BusinessException("A portal account with this email already exists",
                    "PORTAL_EMAIL_TAKEN", HttpStatus.CONFLICT);
        }

        String rawToken = generateInviteToken();
        PortalUser pu = PortalUser.builder()
                .orgId(orgId)
                .contactId(contactId)
                .kind(kindFor(contact))
                .email(normEmail)
                .fullName(fullName != null && !fullName.isBlank() ? fullName.trim() : contact.getDisplayName())
                .status("INVITED")
                .inviteTokenHash(jwtService.hashToken(rawToken))
                .inviteExpiresAt(Instant.now().plus(INVITE_TTL_DAYS, ChronoUnit.DAYS))
                .build();
        portalUserRepository.save(pu);

        Map<String, Object> out = summary(pu);
        out.put("inviteToken", rawToken); // shown once — the org shares the invite link
        out.put("inviteExpiresAt", pu.getInviteExpiresAt());
        return out;
    }

    @Transactional
    public Map<String, Object> resendInvite(UUID portalUserId) {
        PortalUser pu = loadForOrg(portalUserId);
        String rawToken = generateInviteToken();
        pu.setInviteTokenHash(jwtService.hashToken(rawToken));
        pu.setInviteExpiresAt(Instant.now().plus(INVITE_TTL_DAYS, ChronoUnit.DAYS));
        if ("SUSPENDED".equals(pu.getStatus())) pu.setStatus("INVITED");
        portalUserRepository.save(pu);
        Map<String, Object> out = summary(pu);
        out.put("inviteToken", rawToken);
        out.put("inviteExpiresAt", pu.getInviteExpiresAt());
        return out;
    }

    @Transactional
    public PortalUser suspend(UUID portalUserId) {
        PortalUser pu = loadForOrg(portalUserId);
        pu.setStatus("SUSPENDED");
        pu.setTokenVersion(pu.getTokenVersion() + 1); // invalidate existing sessions
        return portalUserRepository.save(pu);
    }

    @Transactional
    public PortalUser reactivate(UUID portalUserId) {
        PortalUser pu = loadForOrg(portalUserId);
        if (pu.getPasswordHash() == null) {
            throw new BusinessException("This account has not accepted its invite yet",
                    "PORTAL_NOT_ACTIVE", HttpStatus.BAD_REQUEST);
        }
        pu.setStatus("ACTIVE");
        return portalUserRepository.save(pu);
    }

    @Transactional
    public void delete(UUID portalUserId) {
        PortalUser pu = loadForOrg(portalUserId);
        pu.setDeleted(true);
        pu.setTokenVersion(pu.getTokenVersion() + 1);
        portalUserRepository.save(pu);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> list() {
        return portalUserRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(requireOrgId())
                .stream().map(this::summary).toList();
    }

    // ── Public: accept invite / login ────────────────────────────────────

    /** Accept an invite and set a password. Returns a logged-in portal session. */
    @Transactional
    public Map<String, Object> acceptInvite(String rawToken, String password) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new BusinessException("Invite token is required", "PORTAL_TOKEN_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        validatePassword(password);
        PortalUser pu = portalUserRepository
                .findByInviteTokenHashAndIsDeletedFalse(jwtService.hashToken(rawToken))
                .orElseThrow(() -> new BusinessException("Invite is invalid or already used",
                        "PORTAL_INVITE_INVALID", HttpStatus.UNAUTHORIZED));
        if (pu.getInviteExpiresAt() == null || pu.getInviteExpiresAt().isBefore(Instant.now())) {
            throw new BusinessException("Invite has expired — ask for a new one",
                    "PORTAL_INVITE_EXPIRED", HttpStatus.UNAUTHORIZED);
        }
        pu.setPasswordHash(passwordEncoder.encode(password));
        pu.setStatus("ACTIVE");
        pu.setInviteTokenHash(null);
        pu.setInviteExpiresAt(null);
        pu.setLastLoginAt(Instant.now());
        portalUserRepository.save(pu);
        return session(pu);
    }

    /** Email + password login. Returns a portal session. */
    @Transactional
    public Map<String, Object> login(String email, String password) {
        String normEmail = normEmail(email);
        BusinessException invalid = new BusinessException("Invalid email or password",
                "PORTAL_BAD_CREDENTIALS", HttpStatus.UNAUTHORIZED);
        if (normEmail == null || password == null) throw invalid;

        PortalUser pu = portalUserRepository.findByEmailIgnoreCaseAndIsDeletedFalse(normEmail)
                .orElseThrow(() -> invalid);
        if (!"ACTIVE".equals(pu.getStatus()) || pu.getPasswordHash() == null) {
            throw new BusinessException("This portal account is not active",
                    "PORTAL_NOT_ACTIVE", HttpStatus.UNAUTHORIZED);
        }
        if (!passwordEncoder.matches(password, pu.getPasswordHash())) {
            throw invalid;
        }
        pu.setLastLoginAt(Instant.now());
        portalUserRepository.save(pu);
        return session(pu);
    }

    /** Change password for the currently-authenticated portal user (TenantContext userId). */
    @Transactional
    public void changePassword(String currentPassword, String newPassword) {
        validatePassword(newPassword);
        UUID portalUserId = TenantContext.getCurrentUserId();
        PortalUser pu = portalUserRepository.findByIdAndIsDeletedFalse(portalUserId)
                .orElseThrow(() -> new BusinessException("Portal session is invalid",
                        "PORTAL_SESSION_INVALID", HttpStatus.UNAUTHORIZED));
        if (pu.getPasswordHash() == null || !passwordEncoder.matches(currentPassword, pu.getPasswordHash())) {
            throw new BusinessException("Current password is incorrect",
                    "PORTAL_BAD_CREDENTIALS", HttpStatus.UNAUTHORIZED);
        }
        pu.setPasswordHash(passwordEncoder.encode(newPassword));
        pu.setTokenVersion(pu.getTokenVersion() + 1);
        portalUserRepository.save(pu);
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private Map<String, Object> session(PortalUser pu) {
        String token = jwtService.generatePortalToken(
                pu.getId(), pu.getOrgId(), pu.getContactId(), pu.getKind(),
                pu.getTokenVersion(), PORTAL_TOKEN_MINUTES);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("token", token);
        out.put("portalUser", summary(pu));
        return out;
    }

    private Map<String, Object> summary(PortalUser pu) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", pu.getId());
        m.put("contactId", pu.getContactId());
        m.put("kind", pu.getKind());
        m.put("email", pu.getEmail());
        m.put("fullName", pu.getFullName());
        m.put("status", pu.getStatus());
        m.put("lastLoginAt", pu.getLastLoginAt());
        return m;
    }

    private PortalUser loadForOrg(UUID portalUserId) {
        return portalUserRepository.findByIdAndOrgIdAndIsDeletedFalse(portalUserId, requireOrgId())
                .orElseThrow(() -> BusinessException.notFound("PortalUser", portalUserId));
    }

    private String generateInviteToken() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return INVITE_PREFIX + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static String kindFor(Contact contact) {
        return contact.getContactType() == ContactType.VENDOR ? "VENDOR" : "CUSTOMER";
    }

    private static void validatePassword(String password) {
        if (password == null || password.length() < 8) {
            throw new BusinessException("Password must be at least 8 characters",
                    "PORTAL_WEAK_PASSWORD", HttpStatus.BAD_REQUEST);
        }
    }

    private static String normEmail(String email) {
        if (email == null) return null;
        String e = email.trim().toLowerCase();
        return e.isEmpty() ? null : e;
    }

    private static UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
