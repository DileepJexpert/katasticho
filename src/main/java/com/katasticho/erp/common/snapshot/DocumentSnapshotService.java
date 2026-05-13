package com.katasticho.erp.common.snapshot;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DocumentSnapshotService {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final PostedDocumentSnapshotRepository snapshotRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    public PostedDocumentSnapshot createSnapshot(
            String documentType,
            UUID documentId,
            String documentNumber,
            Object snapshotObject) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED", HttpStatus.FORBIDDEN);
        }

        return snapshotRepository.findByOrgIdAndDocumentTypeAndDocumentId(orgId, documentType, documentId)
                .orElseGet(() -> {
                    Map<String, Object> snapshot = objectMapper.convertValue(snapshotObject, MAP_TYPE);
                    String hash = computeSnapshotHash(snapshot);
                    return snapshotRepository.save(PostedDocumentSnapshot.builder()
                            .orgId(orgId)
                            .documentType(documentType)
                            .documentId(documentId)
                            .documentNumber(documentNumber)
                            .snapshotJson(snapshot)
                            .snapshotHash(hash)
                            .postedAt(Instant.now())
                            .postedBy(TenantContext.getCurrentUserId())
                            .build());
                });
    }

    @Transactional(readOnly = true)
    public PostedDocumentSnapshot getSnapshot(String documentType, UUID documentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return snapshotRepository.findByOrgIdAndDocumentTypeAndDocumentId(orgId, documentType, documentId)
                .orElseThrow(() -> BusinessException.notFound("PostedDocumentSnapshot", documentId));
    }

    public String computeSnapshotHash(Object snapshotObject) {
        try {
            ObjectMapper canonicalMapper = objectMapper.copy()
                    .configure(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS, true);
            byte[] json = canonicalMapper.writeValueAsBytes(snapshotObject);
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(json));
        } catch (JsonProcessingException | NoSuchAlgorithmException e) {
            throw new BusinessException(
                    "Could not compute posted document snapshot hash",
                    "SNAPSHOT_HASH_FAILED",
                    HttpStatus.INTERNAL_SERVER_ERROR
            );
        }
    }
}
