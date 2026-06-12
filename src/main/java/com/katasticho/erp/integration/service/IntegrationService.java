package com.katasticho.erp.integration.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.integration.entity.IntegrationConfig;
import com.katasticho.erp.integration.entity.IntegrationSyncLog;
import com.katasticho.erp.integration.repository.IntegrationConfigRepository;
import com.katasticho.erp.integration.repository.IntegrationSyncLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class IntegrationService {

    private static final List<String> ALLOWED_TYPES = List.of(
            "TALLY", "ZOHO", "BUSY", "SAP", "CUSTOM");

    private final IntegrationConfigRepository configRepo;
    private final IntegrationSyncLogRepository syncLogRepo;

    // ── Config CRUD ───────────────────────────────────────────────────────────

    @Transactional
    public IntegrationConfig createConfig(String integrationType, String name,
                                          String baseUrl, String rawApiKey,
                                          Map<String, Object> settings) {
        String typeUpper = integrationType.toUpperCase();
        if (!ALLOWED_TYPES.contains(typeUpper)) {
            throw new BusinessException(
                    "Unknown integration type: " + integrationType + ". Allowed: " + ALLOWED_TYPES,
                    "INTEGRATION_UNKNOWN_TYPE");
        }

        IntegrationConfig config = IntegrationConfig.builder()
                .integrationType(typeUpper)
                .name(name)
                .baseUrl(baseUrl)
                .apiKeyHash(rawApiKey != null ? sha256(rawApiKey) : null)
                .settings(settings != null ? settings : Map.of())
                .isActive(true)
                .build();

        return configRepo.save(config);
    }

    @Transactional
    public IntegrationConfig updateConfig(UUID id, String name, String baseUrl,
                                          String rawApiKey, Map<String, Object> settings,
                                          Boolean isActive) {
        UUID orgId = TenantContext.getCurrentOrgId();
        IntegrationConfig config = configRepo.findById(id)
                .filter(c -> c.getOrgId().equals(orgId) && !c.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("IntegrationConfig", id));

        if (name    != null)     config.setName(name);
        if (baseUrl != null)     config.setBaseUrl(baseUrl);
        if (rawApiKey != null)   config.setApiKeyHash(sha256(rawApiKey));
        if (settings != null)    config.setSettings(settings);
        if (isActive != null)    config.setActive(isActive);

        return configRepo.save(config);
    }

    @Transactional
    public void deleteConfig(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        IntegrationConfig config = configRepo.findById(id)
                .filter(c -> c.getOrgId().equals(orgId) && !c.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("IntegrationConfig", id));
        config.setDeleted(true);
        configRepo.save(config);
    }

    public List<IntegrationConfig> listConfigs() {
        return configRepo.findByOrgIdAndIsDeletedFalse(TenantContext.getCurrentOrgId());
    }

    public IntegrationConfig getConfig(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return configRepo.findById(id)
                .filter(c -> c.getOrgId().equals(orgId) && !c.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("IntegrationConfig", id));
    }

    // ── Connection Test ───────────────────────────────────────────────────────

    /**
     * Placeholder connection test — returns success if the config exists and is active.
     * A future implementation would attempt an HTTP handshake to the remote system.
     */
    public Map<String, Object> testConnection(UUID configId) {
        IntegrationConfig config = getConfig(configId);
        if (!config.isActive()) {
            return Map.of("success", false, "message", "Integration is inactive");
        }
        // Placeholder: log attempt
        log.info("Connection test for integration [{}] type={} url={}",
                configId, config.getIntegrationType(), config.getBaseUrl());
        return Map.of(
                "success", true,
                "message", "Connection placeholder — no actual handshake performed",
                "integrationType", config.getIntegrationType(),
                "baseUrl", config.getBaseUrl() != null ? config.getBaseUrl() : ""
        );
    }

    // ── Sync ──────────────────────────────────────────────────────────────────

    /**
     * Create a sync log entry and (placeholder) perform the sync.
     */
    @Transactional
    public IntegrationSyncLog syncData(UUID configId, String syncType, String direction) {
        IntegrationConfig config = getConfig(configId);
        if (!config.isActive()) {
            throw new BusinessException("Integration is inactive", "INTEGRATION_INACTIVE",
                    HttpStatus.CONFLICT);
        }

        UUID orgId = TenantContext.getCurrentOrgId();
        Instant now = Instant.now();

        IntegrationSyncLog logEntry = IntegrationSyncLog.builder()
                .integrationId(configId)
                .syncType(syncType != null ? syncType.toUpperCase() : "GENERAL")
                .direction(direction != null ? direction.toUpperCase() : "EXPORT")
                .status("RUNNING")
                .startedAt(now)
                .build();
        logEntry = syncLogRepo.save(logEntry);

        // Placeholder: simulate completion immediately
        logEntry.setStatus("SUCCESS");
        logEntry.setRecordsProcessed(0);
        logEntry.setRecordsFailed(0);
        logEntry.setCompletedAt(Instant.now());

        // Update last_sync_at on the config
        config.setLastSyncAt(now);
        configRepo.save(config);

        return syncLogRepo.save(logEntry);
    }

    // ── Sync History ──────────────────────────────────────────────────────────

    public List<IntegrationSyncLog> getSyncHistory(UUID configId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        // Validate access
        getConfig(configId);
        return syncLogRepo.findByOrgIdAndIntegrationIdAndIsDeletedFalseOrderByStartedAtDesc(orgId, configId);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String sha256(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}
