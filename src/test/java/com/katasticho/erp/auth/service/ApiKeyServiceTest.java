package com.katasticho.erp.auth.service;

import com.katasticho.erp.auth.dto.CreateApiKeyRequest;
import com.katasticho.erp.auth.dto.CreatedApiKeyResponse;
import com.katasticho.erp.auth.entity.ApiKey;
import com.katasticho.erp.auth.repository.ApiKeyRepository;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ApiKeyServiceTest {

    private final ApiKeyRepository apiKeyRepository = mock(ApiKeyRepository.class);
    private final ApiKeyService service = new ApiKeyService(apiKeyRepository);

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        when(apiKeyRepository.save(any(ApiKey.class))).thenAnswer(inv -> {
            ApiKey k = inv.getArgument(0);
            if (k.getId() == null) k.setId(UUID.randomUUID());
            return k;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void createReturnsPlaintextOnceAndStoresOnlyHash() {
        CreatedApiKeyResponse created = service.create(new CreateApiKeyRequest("Claude Desktop", null));

        // Plaintext returned once, recognizable, never persisted.
        assertThat(created.key()).startsWith("kat_");
        assertThat(created.name()).isEqualTo("Claude Desktop");
        assertThat(created.keyPrefix()).hasSize(12).startsWith("kat_");

        ArgumentCaptor<ApiKey> captor = ArgumentCaptor.forClass(ApiKey.class);
        verify(apiKeyRepository).save(captor.capture());
        ApiKey saved = captor.getValue();
        assertThat(saved.getKeyHash()).isNotEqualTo(created.key());
        assertThat(saved.getKeyHash()).hasSize(64); // SHA-256 hex
        assertThat(saved.getKeyHash()).isEqualTo(service.sha256Hex(created.key()));
        assertThat(saved.getUserId()).isEqualTo(userId);
        assertThat(saved.isActive()).isTrue();
        assertThat(saved.getExpiresAt()).isNull();
    }

    @Test
    void createWithExpirySetsExpiresAt() {
        CreatedApiKeyResponse created = service.create(new CreateApiKeyRequest("Temp", 30));
        assertThat(created.expiresAt()).isNotNull();
        assertThat(created.expiresAt()).isAfter(Instant.now().plusSeconds(29L * 86400));
    }

    @Test
    void resolveUsableKeyMatchesByHash() {
        String raw = "kat_" + "ABCDEFqrstuvwx1234567890";
        ApiKey key = ApiKey.builder()
                .userId(userId).name("k").keyHash(service.sha256Hex(raw)).keyPrefix(raw.substring(0, 12))
                .active(true).build();
        key.setOrgId(orgId);
        when(apiKeyRepository.findByKeyHash(service.sha256Hex(raw))).thenReturn(Optional.of(key));

        assertThat(service.resolveUsableKey(raw)).containsSame(key);
    }

    @Test
    void resolveUsableKeyRejectsNonKatString() {
        assertThat(service.resolveUsableKey("not-a-key")).isEmpty();
        // Never even hashes/looks up a non-kat token.
        verify(apiKeyRepository, org.mockito.Mockito.never()).findByKeyHash(any());
    }

    @Test
    void resolveUsableKeyRejectsRevokedKey() {
        String raw = "kat_revoked_000000000000";
        ApiKey revoked = ApiKey.builder()
                .userId(userId).name("k").keyHash(service.sha256Hex(raw)).keyPrefix(raw.substring(0, 12))
                .active(false).revokedAt(Instant.now()).build();
        when(apiKeyRepository.findByKeyHash(service.sha256Hex(raw))).thenReturn(Optional.of(revoked));

        assertThat(service.resolveUsableKey(raw)).isEmpty();
    }

    @Test
    void revokeMarksInactive() {
        UUID keyId = UUID.randomUUID();
        ApiKey key = ApiKey.builder().userId(userId).name("k").keyHash("h").keyPrefix("kat_xxxxxxxx")
                .active(true).build();
        key.setId(keyId);
        key.setOrgId(orgId);
        when(apiKeyRepository.findByIdAndOrgIdAndIsDeletedFalse(keyId, orgId)).thenReturn(Optional.of(key));

        service.revoke(keyId);

        assertThat(key.isActive()).isFalse();
        assertThat(key.getRevokedAt()).isNotNull();
        verify(apiKeyRepository).save(key);
    }
}
