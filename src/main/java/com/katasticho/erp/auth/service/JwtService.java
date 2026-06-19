package com.katasticho.erp.auth.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {

    private final SecretKey key;
    private final SecretKey platformAdminKey;
    private final SecretKey portalKey;
    private final long accessTokenExpiryMinutes;
    private final long refreshTokenExpiryDays;
    private final long platformAdminExpiryHours;
    private final SecureRandom secureRandom = new SecureRandom();

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.access-token-expiry-minutes}") long accessTokenExpiryMinutes,
            @Value("${app.jwt.refresh-token-expiry-days}") long refreshTokenExpiryDays,
            @Value("${app.jwt.platform-admin-secret}") String platformAdminSecret,
            @Value("${app.jwt.platform-admin-expiry-hours}") long platformAdminExpiryHours
    ) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.platformAdminKey = Keys.hmacShaKeyFor(platformAdminSecret.getBytes(StandardCharsets.UTF_8));
        // Portal tokens are signed with a key derived from (but distinct from) the
        // main secret, so the app's JWT filter can never accept a portal token and
        // vice versa — no extra config required.
        this.portalKey = Keys.hmacShaKeyFor((secret + "::portal-v1").getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiryMinutes = accessTokenExpiryMinutes;
        this.refreshTokenExpiryDays = refreshTokenExpiryDays;
        this.platformAdminExpiryHours = platformAdminExpiryHours;
    }

    public String generateAccessToken(UUID userId, UUID orgId, String role) {
        return generateAccessToken(userId, orgId, role, 0, accessTokenExpiryMinutes);
    }

    public String generateAccessToken(UUID userId, UUID orgId, String role, long expiryMinutes) {
        return generateAccessToken(userId, orgId, role, 0, expiryMinutes);
    }

    public String generateAccessToken(UUID userId, UUID orgId, String role, int tokenVersion) {
        return generateAccessToken(userId, orgId, role, tokenVersion, accessTokenExpiryMinutes);
    }

    public String generateAccessToken(UUID userId, UUID orgId, String role, int tokenVersion, long expiryMinutes) {
        Instant now = Instant.now();
        Instant expiry = now.plusSeconds(expiryMinutes * 60);

        return Jwts.builder()
                .subject(userId.toString())
                .claim("org_id", orgId.toString())
                .claim("role", role)
                .claim("tokenVersion", tokenVersion)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(key)
                .compact();
    }

    public String generatePlatformAdminToken(UUID adminId, String role, int tokenVersion) {
        Instant now = Instant.now();
        Instant expiry = now.plusSeconds(platformAdminExpiryHours * 3600);

        return Jwts.builder()
                .subject(adminId.toString())
                .claim("role", role)
                .claim("tokenVersion", tokenVersion)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(platformAdminKey)
                .compact();
    }

    public Claims parsePlatformAdminToken(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(platformAdminKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (JwtException e) {
            return null;
        }
    }

    public Claims parseCustomerToken(String token) {
        return validateAndExtract(token);
    }

    /** Portal (external customer/vendor) access token, signed with the isolated portal key. */
    public String generatePortalToken(UUID portalUserId, UUID orgId, UUID contactId,
                                      String kind, int tokenVersion, long expiryMinutes) {
        Instant now = Instant.now();
        Instant expiry = now.plusSeconds(expiryMinutes * 60);
        return Jwts.builder()
                .subject(portalUserId.toString())
                .claim("org_id", orgId.toString())
                .claim("contact_id", contactId.toString())
                .claim("kind", kind)
                .claim("portal", true)
                .claim("tokenVersion", tokenVersion)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(portalKey)
                .compact();
    }

    public Claims parsePortalToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(portalKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return Boolean.TRUE.equals(claims.get("portal", Boolean.class)) ? claims : null;
        } catch (JwtException e) {
            return null;
        }
    }

    public String generateRefreshToken() {
        byte[] bytes = new byte[64];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public long getRefreshTokenExpiryDays() {
        return refreshTokenExpiryDays;
    }

    public Claims validateAndExtract(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (JwtException e) {
            return null;
        }
    }

    public UUID extractUserId(Claims claims) {
        return UUID.fromString(claims.getSubject());
    }

    public UUID extractOrgId(Claims claims) {
        return UUID.fromString(claims.get("org_id", String.class));
    }

    public String extractRole(Claims claims) {
        return claims.get("role", String.class);
    }

    public String hashToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(token.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }
}
