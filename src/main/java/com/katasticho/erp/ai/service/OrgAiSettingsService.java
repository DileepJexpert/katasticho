package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.AiModelSettingsRequest;
import com.katasticho.erp.ai.dto.AiModelSettingsResponse;
import com.katasticho.erp.ai.entity.OrgAiSettings;
import com.katasticho.erp.ai.repository.OrgAiSettingsRepository;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class OrgAiSettingsService {

    private final OrgAiSettingsRepository repository;

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
            new org.springframework.web.client.RestTemplate()
                    .getForObject(baseUrl.replaceAll("/$", "") + "/api/tags", String.class);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
