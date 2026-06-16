package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

/**
 * Chat client for any OpenAI-compatible local server — vLLM, LM Studio,
 * llama.cpp's server, text-generation-webui, or Ollama's {@code /v1} endpoint.
 * This is the standard way to serve a self-hosted (and fine-tuned) open model,
 * so one client covers all of them. Hits {@code POST {baseUrl}/v1/chat/completions}.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class OpenAiCompatibleChatClient {

    private final ObjectMapper objectMapper;

    /**
     * @param baseUrl e.g. http://localhost:8000 (vLLM) or http://localhost:1234 (LM Studio)
     * @param model   the served model name (e.g. "katasticho-accounting-lora")
     * @param apiKey  optional bearer token (many local servers ignore it)
     */
    public String complete(String baseUrl, String model, String apiKey,
                           String systemPrompt, String userMessage) {
        try {
            Map<String, Object> body = Map.of(
                    "model", model,
                    "messages", List.of(
                            Map.of("role", "system", "content", systemPrompt),
                            Map.of("role", "user", "content", userMessage)),
                    "stream", false,
                    "temperature", 0.2);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            if (apiKey != null && !apiKey.isBlank()) {
                headers.setBearerAuth(apiKey);
            }

            RestTemplate rt = new RestTemplate();
            ResponseEntity<String> resp = rt.postForEntity(
                    baseUrl.replaceAll("/$", "") + "/v1/chat/completions",
                    new HttpEntity<>(body, headers), String.class);

            if (resp.getBody() == null) return "";
            JsonNode root = objectMapper.readTree(resp.getBody());
            return root.path("choices").path(0).path("message").path("content").asText("");
        } catch (Exception e) {
            log.error("OpenAI-compatible call to {} failed: {}", baseUrl, e.getMessage());
            throw new RuntimeException("Local model service unavailable: " + e.getMessage(), e);
        }
    }
}
