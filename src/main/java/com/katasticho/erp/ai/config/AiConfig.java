package com.katasticho.erp.ai.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

@Configuration
@ConfigurationProperties(prefix = "app.ai")
@Getter
@Setter
public class AiConfig {

    private String anthropicApiKey;
    private String model = "claude-sonnet-4-20250514";
    private int maxTokens = 4096;
    private int maxSqlRows = 100;

    @Bean
    public RestTemplate claudeRestTemplate(RestTemplateBuilder builder) {
        return builder
                .rootUri("https://api.anthropic.com")
                .defaultHeader("x-api-key", anthropicApiKey != null ? anthropicApiKey : "")
                .defaultHeader("anthropic-version", "2023-06-01")
                .defaultHeader("Content-Type", "application/json")
                .setConnectTimeout(Duration.ofSeconds(15))
                .setReadTimeout(Duration.ofSeconds(60))
                .build();
    }
}
