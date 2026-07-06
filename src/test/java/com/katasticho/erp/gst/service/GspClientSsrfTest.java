package com.katasticho.erp.gst.service;

import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * SSRF guard on the GSP outbound URL: an org-admin-configured base URL that is
 * internal/loopback/non-https must be refused BEFORE any server-side request, so
 * the app can't be used as an internal-network probe / metadata oracle.
 */
class GspClientSsrfTest {

    private final RestTemplate gspRestTemplate = mock(RestTemplate.class);
    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);
    private final GspClient client = new GspClient(gspRestTemplate, orgSettingsService);

    private final UUID orgId = UUID.randomUUID();

    private void configure(String baseUrl) {
        when(orgSettingsService.getAll(orgId)).thenReturn(Map.of(
                GspClient.ENABLED, "true",
                GspClient.BASE_URL, baseUrl,
                GspClient.TOKEN, "tok_123"));
    }

    @Test
    void testConnection_cloudMetadataHttp_isRejectedWithoutCalling() {
        configure("http://169.254.169.254/latest/meta-data");
        Map<String, Object> out = client.testConnection(orgId);

        assertThat(out.get("ok")).isEqualTo(false);
        assertThat(out.get("reachable")).isEqualTo(false);
        verify(gspRestTemplate, never()).exchange(any(String.class), any(), any(), any(Class.class));
    }

    @Test
    void testConnection_internalHttpsAddress_isRejectedWithoutCalling() {
        configure("https://10.0.0.5:8500/v1/agent");
        Map<String, Object> out = client.testConnection(orgId);

        assertThat(out.get("ok")).isEqualTo(false);
        verify(gspRestTemplate, never()).exchange(any(String.class), any(), any(), any(Class.class));
    }

    @Test
    void testConnection_loopbackHttps_isRejectedWithoutCalling() {
        configure("https://127.0.0.1/probe");
        Map<String, Object> out = client.testConnection(orgId);

        assertThat(out.get("ok")).isEqualTo(false);
        verify(gspRestTemplate, never()).exchange(any(String.class), any(), any(), any(Class.class));
    }
}
