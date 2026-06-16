package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.AiModelSettingsRequest;
import com.katasticho.erp.ai.dto.AiModelSettingsResponse;
import com.katasticho.erp.ai.entity.OrgAiSettings;
import com.katasticho.erp.ai.repository.OrgAiSettingsRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrgAiSettingsService {

    private final OrgAiSettingsRepository repository;
    private final ObjectMapper objectMapper;

    public AiModelSettingsResponse getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findById(orgId)
                .map(AiModelSettingsResponse::from)
                .orElseGet(AiModelSettingsResponse::defaults);
    }

    @Transactional
    public AiModelSettingsResponse updateSettings(AiModelSettingsRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        OrgAiSettings s = repository.findById(orgId).orElseGet(() -> {
            OrgAiSettings ns = new OrgAiSettings();
            ns.setOrgId(orgId);
            return ns;
        });
        s.setProvider(req.provider());
        s.setModelName(req.modelName());
        s.setBaseUrl(req.baseUrl());
        s.setUpdatedBy(TenantContext.getCurrentUserId());
        return AiModelSettingsResponse.from(repository.save(s));
    }

    public boolean testOllamaConnection(String baseUrl) {
        try {
            new RestTemplate().getForObject(
                    baseUrl.replaceAll("/$", "") + "/api/tags", String.class);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Lists the models actually installed on a local Ollama server (what
     * {@code ollama list} shows), so the user picks from what they have
     * rather than a hardcoded catalogue. Reads Ollama's {@code /api/tags}.
     * Returns an empty list if the server is unreachable.
     */
    public List<String> listInstalledModels(String baseUrl) {
        List<String> names = new ArrayList<>();
        try {
            String body = new RestTemplate().getForObject(
                    baseUrl.replaceAll("/$", "") + "/api/tags", String.class);
            if (body == null) return names;
            JsonNode root = objectMapper.readTree(body);
            for (JsonNode m : root.path("models")) {
                String name = m.path("name").asText(null);
                if (name != null && !name.isBlank()) names.add(name);
            }
        } catch (Exception e) {
            log.warn("Could not list Ollama models at {}: {}", baseUrl, e.getMessage());
        }
        return names;
    }
}
