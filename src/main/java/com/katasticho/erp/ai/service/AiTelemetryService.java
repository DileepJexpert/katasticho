package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.entity.AiModelRun;
import com.katasticho.erp.ai.entity.AiUsageLog;
import com.katasticho.erp.ai.repository.AiModelRunRepository;
import com.katasticho.erp.ai.repository.AiUsageLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
@RequiredArgsConstructor
public class AiTelemetryService {

    private final AiModelRunRepository modelRunRepository;
    private final AiUsageLogRepository usageLogRepository;
    private final ObjectMapper objectMapper;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public AiModelRun recordModelRun(UUID orgId,
                                     String taskType,
                                     String modelName,
                                     String modelVersion,
                                     String provider,
                                     Map<String, Object> inputSnapshot,
                                     Map<String, Object> output,
                                     BigDecimal confidence,
                                     Integer latencyMs) {
        Map<String, Object> safeInput = inputSnapshot == null ? Map.of() : inputSnapshot;
        Map<String, Object> safeOutput = output == null ? Map.of() : output;
        return modelRunRepository.save(AiModelRun.builder()
                .orgId(orgId)
                .taskType(taskType)
                .modelName(modelName)
                .modelVersion(modelVersion)
                .provider(provider)
                .inputHash(hash(canonicalJson(safeInput)))
                .inputSnapshot(safeInput)
                .output(safeOutput)
                .confidence(confidence)
                .latencyMs(latencyMs)
                .build());
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public AiUsageLog recordUsage(UUID orgId,
                                  String feature,
                                  String provider,
                                  String model,
                                  Integer inputTokens,
                                  Integer outputTokens,
                                  BigDecimal estimatedCostUsd,
                                  String entityType,
                                  UUID entityId) {
        return usageLogRepository.save(AiUsageLog.builder()
                .orgId(orgId)
                .feature(feature)
                .provider(provider)
                .model(model)
                .inputTokens(inputTokens)
                .outputTokens(outputTokens)
                .estimatedCostUsd(estimatedCostUsd)
                .entityType(entityType)
                .entityId(entityId)
                .build());
    }

    private String hash(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(input.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    private String canonicalJson(Map<String, Object> input) {
        try {
            return objectMapper.writeValueAsString(new TreeMap<>(input));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to canonicalize AI telemetry input", e);
        }
    }
}
