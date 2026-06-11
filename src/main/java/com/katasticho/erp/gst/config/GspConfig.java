package com.katasticho.erp.gst.config;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

/**
 * HTTP client for talking to a GST Suvidha Provider (GSP) / e-invoice
 * aggregator. Unlike {@code claudeRestTemplate} this has no fixed root URI —
 * the base URL comes from each org's {@code gst.gsp_base_url} setting, so one
 * deployment can serve orgs on different GSPs.
 */
@Configuration
public class GspConfig {

    @Bean
    public RestTemplate gspRestTemplate(RestTemplateBuilder builder) {
        return builder
                .setConnectTimeout(Duration.ofSeconds(15))
                .setReadTimeout(Duration.ofSeconds(45))
                .build();
    }
}
