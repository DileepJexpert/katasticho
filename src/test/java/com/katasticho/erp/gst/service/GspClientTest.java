package com.katasticho.erp.gst.service;

import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GspClientTest {

    @Mock private RestTemplate gspRestTemplate;
    @Mock private OrgSettingsService orgSettingsService;
    private GspClient client;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        client = new GspClient(gspRestTemplate, orgSettingsService);
    }

    private void configured() {
        Map<String, String> s = new HashMap<>();
        s.put(GspClient.ENABLED, "true");
        s.put(GspClient.BASE_URL, "https://api.gsp.example.com");
        s.put(GspClient.TOKEN, "secret");
        s.put(GspClient.GSTIN, "27AABCT1234A1Z5");
        when(orgSettingsService.getAll(orgId)).thenReturn(s);
    }

    @Test
    void testConnection_notConfigured_reportsNotReachable() {
        when(orgSettingsService.getAll(orgId)).thenReturn(new HashMap<>());

        Map<String, Object> r = client.testConnection(orgId);

        assertThat(r.get("ok")).isEqualTo(false);
        assertThat(r.get("reachable")).isEqualTo(false);
    }

    @Test
    void testConnection_hostAnswers200_isReachable() {
        configured();
        when(gspRestTemplate.exchange(eq("https://api.gsp.example.com"), eq(HttpMethod.GET),
                any(HttpEntity.class), eq(String.class)))
                .thenReturn(ResponseEntity.ok("pong"));

        Map<String, Object> r = client.testConnection(orgId);

        assertThat(r.get("ok")).isEqualTo(true);
        assertThat(r.get("reachable")).isEqualTo(true);
        assertThat(r.get("statusCode")).isEqualTo(200);
    }

    @Test
    void testConnection_hostAnswers401_stillReachable() {
        configured();
        when(gspRestTemplate.exchange(anyString(), eq(HttpMethod.GET),
                any(HttpEntity.class), eq(String.class)))
                .thenThrow(new HttpClientErrorException(HttpStatus.UNAUTHORIZED));

        Map<String, Object> r = client.testConnection(orgId);

        // An HTTP error status means the host is up — credentials may just be wrong.
        assertThat(r.get("ok")).isEqualTo(true);
        assertThat(r.get("reachable")).isEqualTo(true);
        assertThat(r.get("statusCode")).isEqualTo(401);
    }

    @Test
    void testConnection_transportError_isUnreachable() {
        configured();
        when(gspRestTemplate.exchange(anyString(), eq(HttpMethod.GET),
                any(HttpEntity.class), eq(String.class)))
                .thenThrow(new ResourceAccessException("Connection refused"));

        Map<String, Object> r = client.testConnection(orgId);

        assertThat(r.get("ok")).isEqualTo(false);
        assertThat(r.get("reachable")).isEqualTo(false);
    }
}
