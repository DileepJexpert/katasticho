package com.katasticho.erp.auth.service;

import com.katasticho.erp.auth.dto.ApiKeyResponse;
import com.katasticho.erp.auth.dto.CreateApiKeyRequest;
import com.katasticho.erp.auth.dto.CreatedApiKeyResponse;
import com.katasticho.erp.auth.entity.ApiKey;
import com.katasticho.erp.auth.repository.ApiKeyRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Mint, list, revoke, and resolve org-scoped API keys.
 *
 * <p>Keys look like {@code kat_<43 url-safe chars>}. Only the SHA-256 hash is
 * stored; the plaintext is returned once at creation and never again.
 */
@Service
@RequiredArgsConstructor
public class ApiKeyService {

    /** Public prefix so a key is recognizable and the auth filter can fast-skip non-keys. */
    public static final String KEY_PREFIX = "kat_";
    private static final int DISPLAY_PREFIX_LEN = 12;
    private static final long TOUCH_THROTTLE_MINUTES = 5;

    private final ApiKeyRepository apiKeyRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public CreatedApiKeyResponse create(CreateApiKeyRequest request) {
        UUID orgId = requireOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException("User context is required", "USER_CONTEXT_REQUIRED");
        }

        String rawKey = generateRawKey();
        ApiKey key = ApiKey.builder()
                .userId(userId)
                .name(request.name().trim())
                .keyHash(sha256Hex(rawKey))
                .keyPrefix(rawKey.substring(0, DISPLAY_PREFIX_LEN))
                .expiresAt(request.expiresInDays() != null && request.expiresInDays() > 0
                        ? Instant.now().plus(request.expiresInDays(), ChronoUnit.DAYS)
                        : null)
                .active(true)
                .build();
        key.setOrgId(orgId);
        key = apiKeyRepository.save(key);

        return new CreatedApiKeyResponse(
                key.getId(), key.getName(), key.getKeyPrefix(), rawKey,
                key.getExpiresAt(), key.getCreatedAt());
    }

    @Transactional(readOnly = true)
    public List<ApiKeyResponse> list() {
        return apiKeyRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(requireOrgId())
                .stream().map(ApiKeyResponse::from).toList();
    }

    @Transactional
    public void revoke(UUID id) {
        UUID orgId = requireOrgId();
        ApiKey key = apiKeyRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ApiKey", id));
        key.setActive(false);
        key.setRevokedAt(Instant.now());
        apiKeyRepository.save(key);
    }

    /** Resolve a raw key to its usable {@link ApiKey}, or empty. Used by the auth filter. */
    @Transactional(readOnly = true)
    public Optional<ApiKey> resolveUsableKey(String rawKey) {
        if (rawKey == null || !rawKey.startsWith(KEY_PREFIX)) {
            return Optional.empty();
        }
        return apiKeyRepository.findByKeyHash(sha256Hex(rawKey)).filter(ApiKey::isUsable);
    }

    /** Throttled best-effort "last used" stamp so we don't write on every call. */
    @Transactional
    public void touchLastUsed(UUID keyId) {
        apiKeyRepository.findById(keyId).ifPresent(key -> {
            Instant now = Instant.now();
            if (key.getLastUsedAt() == null
                    || key.getLastUsedAt().isBefore(now.minus(TOUCH_THROTTLE_MINUTES, ChronoUnit.MINUTES))) {
                key.setLastUsedAt(now);
                apiKeyRepository.save(key);
            }
        });
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private String generateRawKey() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return KEY_PREFIX + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
