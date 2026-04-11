package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.config.AiConfig;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Low-level client for calling the Anthropic Messages API via RestTemplate.
 * Used by NlpQueryService and BillScanService.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ClaudeApiClient {

    private final RestTemplate claudeRestTemplate;
    private final AiConfig aiConfig;
    private final ObjectMapper objectMapper;

    /**
     * Send a text-only message to Claude and get the response text.
     */
    public String sendMessage(String systemPrompt, String userMessage) {
        var requestBody = Map.of(
                "model", aiConfig.getModel(),
                "max_tokens", aiConfig.getMaxTokens(),
                "system", systemPrompt,
                "messages", List.of(
                        Map.of("role", "user", "content", userMessage)
                )
        );

        return callApi(requestBody);
    }

    /**
     * Send a message with an image (base64) to Claude Vision.
     */
    public String sendMessageWithImage(String systemPrompt, String textMessage,
                                        String base64Image, String mediaType) {
        Map<String, Object> imageContent = new java.util.HashMap<>();
        imageContent.put("type", "image");
        imageContent.put("source", Map.of(
                "type", "base64",
                "media_type", mediaType,
                "data", base64Image
        ));

        Map<String, Object> textContent = new java.util.HashMap<>();
        textContent.put("type", "text");
        textContent.put("text", textMessage);

        List<Map<String, Object>> content = new ArrayList<>();
        content.add(imageContent);
        content.add(textContent);

        var requestBody = Map.of(
                "model", aiConfig.getModel(),
                "max_tokens", aiConfig.getMaxTokens(),
                "system", systemPrompt,
                "messages", List.of(
                        Map.of("role", "user", "content", content)
                )
        );

        return callApi(requestBody);
    }

    private String callApi(Map<String, Object> requestBody) {
        try {
            ResponseEntity<String> response = claudeRestTemplate.postForEntity(
                    "/v1/messages", requestBody, String.class);

            if (response.getBody() == null) {
                log.warn("Empty response from Claude API");
                return "";
            }

            JsonNode root = objectMapper.readTree(response.getBody());
            JsonNode contentArray = root.path("content");

            if (contentArray.isArray() && !contentArray.isEmpty()) {
                return contentArray.get(0).path("text").asText("");
            }

            log.warn("No content in Claude API response");
            return "";
        } catch (Exception e) {
            log.error("Claude API call failed: {}", e.getMessage(), e);
            throw new RuntimeException("AI service unavailable: " + e.getMessage(), e);
        }
    }
}
