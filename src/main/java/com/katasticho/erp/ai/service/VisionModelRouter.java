package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.config.AiConfig;
import com.katasticho.erp.ai.entity.OrgAiSettings;
import com.katasticho.erp.ai.repository.OrgAiSettingsRepository;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class VisionModelRouter {

    private final ClaudeApiClient claudeApiClient;
    private final OllamaVisionClient ollamaVisionClient;
    private final OrgAiSettingsRepository settingsRepository;
    private final AiConfig aiConfig;

    public String sendMessage(String systemPrompt, String userMessage) {
        OrgAiSettings s = getSettings();
        if ("OLLAMA".equals(s.getProvider())) {
            return ollamaVisionClient.callOllamaFull(s.getBaseUrl(), s.getModelName(),
                    systemPrompt + "\n\n" + userMessage, null);
        }
        return claudeApiClient.sendMessage(systemPrompt, userMessage);
    }

    public String sendMessageWithImage(String systemPrompt, String textMessage,
                                       String base64Image, String mediaType) {
        OrgAiSettings s = getSettings();
        if ("OLLAMA".equals(s.getProvider())) {
            return ollamaVisionClient.callOllamaFull(s.getBaseUrl(), s.getModelName(),
                    systemPrompt + "\n\n" + textMessage, base64Image);
        }
        return claudeApiClient.sendMessageWithImage(systemPrompt, textMessage, base64Image, mediaType);
    }

    private OrgAiSettings getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) return defaultSettings();
        return settingsRepository.findById(orgId).orElseGet(this::defaultSettings);
    }

    private OrgAiSettings defaultSettings() {
        OrgAiSettings s = new OrgAiSettings();
        s.setProvider(aiConfig.getDefaultProvider());
        if ("OLLAMA".equals(s.getProvider())) {
            s.setModelName(aiConfig.getOllamaModel());
            s.setBaseUrl(aiConfig.getOllamaBaseUrl());
        } else {
            s.setModelName(aiConfig.getModel());
        }
        return s;
    }
}
