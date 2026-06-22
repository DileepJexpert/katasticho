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
    private final OpenAiCompatibleChatClient openAiCompatibleChatClient;
    private final OrgAiSettingsRepository settingsRepository;
    private final AiConfig aiConfig;

    public String sendMessage(String systemPrompt, String userMessage) {
        OrgAiSettings s = getSettings();
        return switch (provider(s)) {
            case "OLLAMA" -> ollamaVisionClient.callOllamaFull(s.getBaseUrl(), s.getModelName(),
                    systemPrompt + "\n\n" + userMessage, null);
            case "OPENAI_COMPAT" -> openAiCompatibleChatClient.complete(
                    s.getBaseUrl(), s.getModelName(), null, systemPrompt, userMessage);
            default -> claudeApiClient.sendMessage(systemPrompt, userMessage);
        };
    }

    public String sendMessageWithImage(String systemPrompt, String textMessage,
                                       String base64Image, String mediaType) {
        OrgAiSettings s = getSettings();
        // Vision: Ollama handles images natively; OPENAI_COMPAT vision varies by
        // server, so route it through the Ollama-style path too when local.
        if ("OLLAMA".equals(provider(s)) || "OPENAI_COMPAT".equals(provider(s))) {
            return ollamaVisionClient.callOllamaFull(s.getBaseUrl(), s.getModelName(),
                    systemPrompt + "\n\n" + textMessage, base64Image);
        }
        return claudeApiClient.sendMessageWithImage(systemPrompt, textMessage, base64Image, mediaType);
    }

    private static String provider(OrgAiSettings s) {
        return s.getProvider() == null ? "CLAUDE" : s.getProvider().toUpperCase();
    }

    private OrgAiSettings getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) return defaultSettings();
        return settingsRepository.findById(orgId).orElseGet(this::defaultSettings);
    }

    public boolean isUsingLocal() {
        return aiConfig.isUseLocal();
    }

    private OrgAiSettings defaultSettings() {
        OrgAiSettings s = new OrgAiSettings();
        String provider = aiConfig.isUseLocal() ? "OLLAMA" : aiConfig.getDefaultProvider();
        s.setProvider(provider);
        if ("OLLAMA".equals(provider)) {
            s.setModelName(aiConfig.getOllamaModel());
            s.setBaseUrl(aiConfig.getOllamaBaseUrl());
        } else {
            s.setModelName(aiConfig.getModel());
        }
        return s;
    }
}
