package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.*;

import java.util.*;

@Component
@RequiredArgsConstructor
@Slf4j
public class OllamaVisionClient implements VisionModelClient {

    private final ObjectMapper objectMapper;

    @Override
    public String sendMessage(String systemPrompt, String userMessage) {
        // Ollama doesn't have system prompt in same way; prepend to user message
        return callOllama(null, systemPrompt + "\n\n" + userMessage, null);
    }

    @Override
    public String sendMessageWithImage(String systemPrompt, String textMessage,
                                       String base64Image, String mediaType) {
        return callOllama(null, systemPrompt + "\n\n" + textMessage, base64Image);
    }

    // baseUrl and model are set per-call via this package-private method
    String callWithConfig(String baseUrl, String model, String systemPrompt,
                          String textMessage, String base64Image) {
        return callOllamaFull(baseUrl, model, systemPrompt + "\n\n" + textMessage, base64Image);
    }

    private String callOllama(String ignored, String message, String base64Image) {
        // This variant is only called through VisionModelRouter which sets config
        throw new UnsupportedOperationException("Use VisionModelRouter, not OllamaVisionClient directly");
    }

    String callOllamaFull(String baseUrl, String model, String message, String base64Image) {
        try {
            Map<String, Object> msgMap = new HashMap<>();
            msgMap.put("role", "user");
            msgMap.put("content", message);
            if (base64Image != null) {
                msgMap.put("images", List.of(base64Image));
            }

            Map<String, Object> body = Map.of(
                    "model", model,
                    "messages", List.of(msgMap),
                    "stream", false
            );

            RestTemplate rt = new RestTemplate();
            ResponseEntity<String> resp = rt.postForEntity(
                    baseUrl.replaceAll("/$", "") + "/api/chat",
                    new HttpEntity<>(body, jsonHeaders()),
                    String.class
            );

            if (resp.getBody() == null) return "";
            JsonNode root = objectMapper.readTree(resp.getBody());
            return root.path("message").path("content").asText("");
        } catch (Exception e) {
            log.error("Ollama API call failed: {}", e.getMessage(), e);
            throw new RuntimeException("Ollama service unavailable: " + e.getMessage(), e);
        }
    }

    private HttpHeaders jsonHeaders() {
        HttpHeaders h = new HttpHeaders();
        h.setContentType(MediaType.APPLICATION_JSON);
        return h;
    }
}
