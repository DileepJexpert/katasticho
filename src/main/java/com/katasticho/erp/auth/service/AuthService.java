package com.katasticho.erp.auth.service;

import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.auth.dto.*;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.entity.RefreshToken;
import com.katasticho.erp.auth.entity.UserInvitation;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.auth.repository.RefreshTokenRepository;
import com.katasticho.erp.auth.repository.UserInvitationRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.service.UomService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxSeedService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final AppUserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserInvitationRepository invitationRepository;
    private final OrganisationRepository organisationRepository;
    private final JwtService jwtService;
    private final OtpService otpService;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;
    private final JdbcTemplate jdbcTemplate;
    private final UomService uomService;
    private final AccountService accountService;
    private final DefaultAccountService defaultAccountService;
    private final TaxSeedService taxSeedService;

    public void requestOtp(OtpRequest request) {
        otpService.generateAndStore(request.phone());
    }

    @Transactional
    public AuthResponse verifyOtpAndLogin(OtpVerifyRequest request) {
        boolean valid = otpService.verify(request.phone(), request.otp());
        if (!valid) {
            throw new BusinessException("Invalid or expired OTP", "AUTH_INVALID_OTP", HttpStatus.UNAUTHORIZED);
        }

        // Find user by phone (across all orgs for now — phone OTP login returns first match)
        AppUser user = userRepository.findByPhoneAndIsDeletedFalse(request.phone())
                .orElseThrow(() -> new BusinessException(
                        "No account found for this phone. Please sign up first.",
                        "AUTH_USER_NOT_FOUND", HttpStatus.NOT_FOUND));

        if (!user.isActive()) {
            throw new BusinessException("Account is deactivated", "AUTH_ACCOUNT_INACTIVE", HttpStatus.FORBIDDEN);
        }

        user.resetFailedLogins();
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        Organisation org = organisationRepository.findById(user.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", user.getOrgId()));

        return buildAuthResponse(user, org);
    }

    @Transactional
    public AuthResponse signup(SignupRequest request) {
        // Verify OTP first
        boolean valid = otpService.verify(request.phone(), request.otp());
        if (!valid) {
            throw new BusinessException("Invalid or expired OTP", "AUTH_INVALID_OTP", HttpStatus.UNAUTHORIZED);
        }

        // Check if phone already exists
        if (userRepository.existsByPhoneAndIsDeletedFalse(request.phone())) {
            throw new BusinessException("Phone number already registered", "AUTH_PHONE_EXISTS", HttpStatus.CONFLICT);
        }

        // Create organisation — saveAndFlush so the INSERT hits the DB
        // immediately. We need the row committed to the current txn before
        // the raw JdbcTemplate branch insert below, otherwise the branch FK
        // to organisation.id would fail (Hibernate's write-behind cache
        // would still be holding the org insert).
        Organisation org = Organisation.builder()
                .name(request.orgName())
                .industry(request.industry())
                .build();
        org = organisationRepository.saveAndFlush(org);

        // Bootstrap: every org gets a default branch on day 1. All future
        // warehouses / invoices / etc. inherit this branch unless the user
        // explicitly sets another. The unique partial index enforces one
        // default per org at the DB level.
        UUID defaultBranchId = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO branch (id, org_id, code, name, is_default, is_active) " +
                "VALUES (?, ?, 'HO', 'Head Office', TRUE, TRUE)",
                defaultBranchId, org.getId());

        uomService.seedDefaultsForOrg(org.getId());
        accountService.seedFromTemplate(org.getId(), org.getIndustry());
        // Must run AFTER CoA seeding — looks up account rows by default code.
        defaultAccountService.seedDefaultsForOrg(org.getId());
        // Tax groups + rates + GL account bindings — must run after CoA seeding
        // so that findAccountId("1500"/"2020"/etc.) can resolve the GL accounts.
        taxSeedService.seedForOrg(org);

        // Bootstrap: every org gets a default warehouse tied to the default
        // branch. Without this, CSV import / stock movements fail with
        // INV_NO_DEFAULT_WAREHOUSE.
        jdbcTemplate.update(
                "INSERT INTO warehouse (id, org_id, branch_id, code, name, is_default, is_active, is_deleted, created_at, updated_at) " +
                "VALUES (?, ?, ?, 'MAIN', 'Main Warehouse', TRUE, TRUE, FALSE, now(), now())",
                UUID.randomUUID(), org.getId(), defaultBranchId);

        // Create owner user — saveAndFlush for the same write-behind reason
        // (we raw-UPDATE the branch_id column below).
        AppUser user = AppUser.builder()
                .phone(request.phone())
                .fullName(request.fullName())
                .role("OWNER")
                .build();
        user.setOrgId(org.getId());
        user.setLastLoginAt(Instant.now());
        user = userRepository.saveAndFlush(user);

        // Stamp the owner with the default branch via SQL — branchId is not
        // yet on the AppUser entity; Hibernate validate mode ignores extra
        // DB columns, so we set it out-of-band until the entity is extended.
        jdbcTemplate.update(
                "UPDATE app_user SET branch_id = ? WHERE id = ?",
                defaultBranchId, user.getId());

        auditService.logSync(org.getId(), user.getId(), "APP_USER", user.getId(),
                "CREATE", null, "{\"action\":\"signup\"}");

        log.info("New org created: {} ({}), owner: {}", org.getName(), org.getId(), user.getFullName());
        return buildAuthResponse(user, org);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        // Email login needs to search across orgs — for MVP, find first match
        // In production, the login flow would include org selection
        AppUser user = userRepository.findByPhoneAndIsDeletedFalse(request.email())
                .or(() -> {
                    // Try email across all orgs
                    return userRepository.findAll().stream()
                            .filter(u -> request.email().equalsIgnoreCase(u.getEmail()))
                            .filter(u -> !u.isDeleted())
                            .findFirst();
                })
                .orElseThrow(() -> new BusinessException(
                        "Invalid credentials", "AUTH_BAD_CREDENTIALS", HttpStatus.UNAUTHORIZED));

        if (user.isLocked()) {
            throw new BusinessException("Account is locked. Try again later.",
                    "AUTH_ACCOUNT_LOCKED", HttpStatus.TOO_MANY_REQUESTS);
        }

        if (!user.isActive()) {
            throw new BusinessException("Account is deactivated", "AUTH_ACCOUNT_INACTIVE", HttpStatus.FORBIDDEN);
        }

        if (user.getPasswordHash() == null || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            user.incrementFailedLogins();
            if (user.getFailedLoginCount() >= 5) {
                user.lock(30);
                log.warn("User {} locked after 5 failed password attempts", user.getId());
            }
            userRepository.save(user);
            throw new BusinessException("Invalid credentials", "AUTH_BAD_CREDENTIALS", HttpStatus.UNAUTHORIZED);
        }

        user.resetFailedLogins();
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        Organisation org = organisationRepository.findById(user.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", user.getOrgId()));

        return buildAuthResponse(user, org);
    }

    @Transactional
    public AuthResponse refreshToken(RefreshRequest request) {
        String tokenHash = jwtService.hashToken(request.refreshToken());

        RefreshToken stored = refreshTokenRepository.findByTokenHashAndRevokedAtIsNull(tokenHash)
                .orElseThrow(() -> new BusinessException(
                        "Invalid or revoked refresh token", "AUTH_INVALID_REFRESH", HttpStatus.UNAUTHORIZED));

        if (stored.isExpired()) {
            stored.revoke();
            refreshTokenRepository.save(stored);
            throw new BusinessException("Refresh token expired", "AUTH_REFRESH_EXPIRED", HttpStatus.UNAUTHORIZED);
        }

        // Revoke old token (rotation)
        stored.revoke();
        refreshTokenRepository.save(stored);

        AppUser user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> BusinessException.notFound("User", stored.getUserId()));

        Organisation org = organisationRepository.findById(user.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", user.getOrgId()));

        return buildAuthResponse(user, org);
    }

    @Transactional
    public void logout(RefreshRequest request) {
        String tokenHash = jwtService.hashToken(request.refreshToken());
        refreshTokenRepository.findByTokenHashAndRevokedAtIsNull(tokenHash)
                .ifPresent(token -> {
                    token.revoke();
                    refreshTokenRepository.save(token);
                });
    }

    @Transactional
    public UserInvitation invite(InviteRequest request, UUID orgId, UUID invitedBy) {
        if (request.email() == null && request.phone() == null) {
            throw new BusinessException("Email or phone is required", "AUTH_INVITE_NO_CONTACT", HttpStatus.BAD_REQUEST);
        }

        String token = UUID.randomUUID().toString();
        UserInvitation invitation = UserInvitation.builder()
                .orgId(orgId)
                .email(request.email())
                .phone(request.phone())
                .role(request.role())
                .token(token)
                .invitedBy(invitedBy)
                .expiresAt(Instant.now().plus(72, ChronoUnit.HOURS))
                .build();

        invitation = invitationRepository.save(invitation);
        log.info("Invitation created for {} with role {} in org {}",
                request.email() != null ? request.email() : request.phone(), request.role(), orgId);

        return invitation;
    }

    @Transactional
    public AuthResponse acceptInvitation(InviteAcceptRequest request) {
        UserInvitation invitation = invitationRepository.findByTokenAndAcceptedAtIsNull(request.token())
                .orElseThrow(() -> new BusinessException(
                        "Invalid or already used invitation", "AUTH_INVITE_INVALID", HttpStatus.BAD_REQUEST));

        if (invitation.isExpired()) {
            throw new BusinessException("Invitation has expired", "AUTH_INVITE_EXPIRED", HttpStatus.BAD_REQUEST);
        }

        // Create user in the org
        AppUser user = AppUser.builder()
                .fullName(request.fullName())
                .email(invitation.getEmail())
                .phone(invitation.getPhone())
                .role(invitation.getRole())
                .passwordHash(request.password() != null ? passwordEncoder.encode(request.password()) : null)
                .build();
        user.setOrgId(invitation.getOrgId());
        user = userRepository.save(user);

        // Mark invitation as accepted
        invitation.setAcceptedAt(Instant.now());
        invitationRepository.save(invitation);

        Organisation org = organisationRepository.findById(invitation.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", invitation.getOrgId()));

        auditService.logSync(org.getId(), user.getId(), "APP_USER", user.getId(),
                "CREATE", null, "{\"action\":\"invite_accepted\"}");

        return buildAuthResponse(user, org);
    }

    public AuthResponse.UserInfo getCurrentUser(UUID userId, UUID orgId) {
        AppUser user = userRepository.findByIdAndOrgIdAndIsDeletedFalse(userId, orgId)
                .orElseThrow(() -> BusinessException.notFound("User", userId));
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        return new AuthResponse.UserInfo(
                user.getId(), user.getOrgId(), user.getFullName(),
                user.getEmail(), user.getPhone(), user.getRole(), org.getName());
    }

    private AuthResponse buildAuthResponse(AppUser user, Organisation org) {
        String accessToken = jwtService.generateAccessToken(user.getId(), user.getOrgId(), user.getRole());
        String refreshToken = jwtService.generateRefreshToken();

        // Store refresh token hash
        RefreshToken tokenEntity = RefreshToken.builder()
                .userId(user.getId())
                .tokenHash(jwtService.hashToken(refreshToken))
                .expiresAt(Instant.now().plus(jwtService.getRefreshTokenExpiryDays(), ChronoUnit.DAYS))
                .build();
        refreshTokenRepository.save(tokenEntity);

        AuthResponse.UserInfo userInfo = new AuthResponse.UserInfo(
                user.getId(), user.getOrgId(), user.getFullName(),
                user.getEmail(), user.getPhone(), user.getRole(), org.getName());

        return new AuthResponse(accessToken, refreshToken, userInfo);
    }
}
