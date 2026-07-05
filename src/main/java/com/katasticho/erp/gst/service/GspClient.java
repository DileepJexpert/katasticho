package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Direct GSP / e-invoice-aggregator API client. Posts the INV-01 (e-invoice)
 * and NIC (e-way bill) payloads we already build to a configurable aggregator
 * endpoint and returns the parsed response, so an org with GSP credentials can
 * generate IRNs / EWBs in one click instead of the manual download-JSON →
 * upload-on-portal → paste-result round trip.
 *
 * <p>Provider-agnostic by design: it targets the common aggregator REST shape
 * (Masters India, ClearTax, etc.) — bearer/API-key auth in headers + the JSON
 * payload as the body — rather than NIC's raw RSA/AES handshake, which
 * aggregators abstract away. Until an org fills in {@code gst.gsp_*} settings
 * this client is inert and the manual flow is unchanged.
 *
 * <p>Settings (all under {@code org_settings}):
 * <ul>
 *   <li>{@code gst.gsp_enabled} — master switch</li>
 *   <li>{@code gst.gsp_provider} — free-text label (e.g. "MastersIndia")</li>
 *   <li>{@code gst.gsp_base_url} — aggregator base, e.g. https://api.example.com</li>
 *   <li>{@code gst.gsp_einvoice_path} — path appended to base for IRN generate</li>
 *   <li>{@code gst.gsp_ewaybill_path} — path appended to base for EWB generate</li>
 *   <li>{@code gst.gsp_token} — bearer token / API key sent as Authorization</li>
 *   <li>{@code gst.gsp_gstin} — the org's GSTIN, sent as a header most GSPs require</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class GspClient {

    public static final String ENABLED = "gst.gsp_enabled";
    public static final String PROVIDER = "gst.gsp_provider";
    public static final String BASE_URL = "gst.gsp_base_url";
    public static final String EINVOICE_PATH = "gst.gsp_einvoice_path";
    public static final String EWAYBILL_PATH = "gst.gsp_ewaybill_path";
    public static final String GSTR2B_PATH = "gst.gsp_gstr2b_path";
    public static final String GSTR2A_PATH = "gst.gsp_gstr2a_path";
    public static final String TOKEN = "gst.gsp_token";
    public static final String GSTIN = "gst.gsp_gstin";

    private final RestTemplate gspRestTemplate;
    private final OrgSettingsService orgSettingsService;

    /** A GSP can be called only when enabled and given a base URL + token. */
    public boolean isConfigured(UUID orgId) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        return "true".equalsIgnoreCase(s.getOrDefault(ENABLED, "false"))
                && notBlank(s.get(BASE_URL))
                && notBlank(s.get(TOKEN));
    }

    public Map<String, Object> generateEInvoice(UUID orgId, Map<String, Object> payload) {
        return post(orgId, path(orgId, EINVOICE_PATH, "/einvoice/generate"), payload);
    }

    public Map<String, Object> generateEwayBill(UUID orgId, Map<String, Object> payload) {
        return post(orgId, path(orgId, EWAYBILL_PATH, "/ewaybill/generate"), payload);
    }

    /**
     * GET the GSTR-2B JSON for a return period from the aggregator. The shape
     * mirrors the portal-uploaded JSON so {@link Gstr2bReconService#upload}
     * can ingest it unchanged. Common aggregator pattern: GET with gstin +
     * period query params, bearer token + gstin header.
     */
    public Map<String, Object> fetch2b(UUID orgId, String returnPeriod) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        String url = UriComponentsBuilder
                .fromHttpUrl(path(orgId, GSTR2B_PATH, "/gstr2b/fetch"))
                .queryParam("gstin", s.getOrDefault(GSTIN, ""))
                .queryParam("period", returnPeriod)
                .build(true)
                .toUriString();
        return exchange(orgId, url, HttpMethod.GET, null);
    }

    /**
     * Pull the GSTR-2B JSON for a return period via the aggregator-style API
     * shape (rtnprd/gstin query params, GET with bearer + gstin header).
     * Companion to {@link #fetch2b} which uses the simpler period= shape.
     */
    public Map<String, Object> fetchGstr2b(UUID orgId, String returnPeriod) {
        return getReturn(orgId, path(orgId, GSTR2B_PATH, "/gstr2b/fetch"), returnPeriod);
    }

    /**
     * Pull the GSTR-2A (the <em>real-time</em>, continuously-updating feed) for a
     * return period. Unlike 2B — which freezes on the 14th, after the filing
     * deadline — 2A reflects each supplier's GSTR-1 as it is filed, so it is the
     * signal an ITC-at-risk monitor needs to warn before the cutoff locks.
     */
    public Map<String, Object> fetchGstr2a(UUID orgId, String returnPeriod) {
        return getReturn(orgId, path(orgId, GSTR2A_PATH, "/gstr2a/fetch"), returnPeriod);
    }

    private Map<String, Object> getReturn(UUID orgId, String base, String returnPeriod) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        StringBuilder url = new StringBuilder(base)
                .append(base.contains("?") ? "&" : "?")
                .append("rtnprd=").append(returnPeriod);
        if (notBlank(s.get(GSTIN))) {
            url.append("&gstin=").append(s.get(GSTIN).trim());
        }
        return get(orgId, url.toString());
    }

    /**
     * Probe whether the configured GSP host is reachable, without generating
     * anything. A GET to the base URL: any HTTP response (even 401/404) means
     * the host is up and the credentials reach it; only a transport error means
     * unreachable. Never throws — returns a structured result for the UI.
     */
    public Map<String, Object> testConnection(UUID orgId) {
        Map<String, Object> out = new LinkedHashMap<>();
        if (!isConfigured(orgId)) {
            out.put("ok", false);
            out.put("reachable", false);
            out.put("message", "Enable GSP and set a base URL + token first.");
            return out;
        }
        Map<String, String> s = orgSettingsService.getAll(orgId);
        String base = s.getOrDefault(BASE_URL, "").trim();
        if (base.endsWith("/")) base = base.substring(0, base.length() - 1);

        // SSRF guard: refuse to probe an internal/loopback/non-https host. Return
        // a structured "not allowed" result (testConnection never throws).
        try {
            com.katasticho.erp.common.net.OutboundUrlGuard.validate(base, "GSP_URL");
        } catch (BusinessException be) {
            out.put("ok", false);
            out.put("reachable", false);
            out.put("message", be.getMessage());
            return out;
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(s.getOrDefault(TOKEN, ""));
        if (notBlank(s.get(GSTIN))) headers.set("gstin", s.get(GSTIN).trim());

        try {
            ResponseEntity<String> resp = gspRestTemplate.exchange(
                    base, org.springframework.http.HttpMethod.GET,
                    new HttpEntity<>(headers), String.class);
            return reachable(out, resp.getStatusCode().value());
        } catch (org.springframework.web.client.HttpStatusCodeException e) {
            // The host answered with an error status — still up and addressable.
            return reachable(out, e.getStatusCode().value());
        } catch (RestClientException e) {
            log.warn("GSP test-connection failed for org {}: {}", orgId, e.getMessage());
            out.put("ok", false);
            out.put("reachable", false);
            out.put("message", "Could not reach the GSP host: " + e.getMessage());
            return out;
        }
    }

    private Map<String, Object> reachable(Map<String, Object> out, int statusCode) {
        out.put("ok", true);
        out.put("reachable", true);
        out.put("statusCode", statusCode);
        out.put("message", "GSP host reachable (HTTP " + statusCode + ").");
        return out;
    }

    /** Settings map for the UI; the token is masked, never echoed in full. */
    public Map<String, Object> settings(UUID orgId) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("enabled", "true".equalsIgnoreCase(s.getOrDefault(ENABLED, "false")));
        out.put("provider", s.getOrDefault(PROVIDER, ""));
        out.put("baseUrl", s.getOrDefault(BASE_URL, ""));
        out.put("einvoicePath", s.getOrDefault(EINVOICE_PATH, ""));
        out.put("ewaybillPath", s.getOrDefault(EWAYBILL_PATH, ""));
        out.put("gstr2bPath", s.getOrDefault(GSTR2B_PATH, ""));
        out.put("gstr2aPath", s.getOrDefault(GSTR2A_PATH, ""));
        out.put("gstin", s.getOrDefault(GSTIN, ""));
        out.put("tokenSet", notBlank(s.get(TOKEN)));
        return out;
    }

    // ── internals ────────────────────────────────────────────────────────

    private Map<String, Object> post(UUID orgId, String url, Map<String, Object> payload) {
        return exchange(orgId, url, HttpMethod.POST, payload);
    }

    private Map<String, Object> exchange(UUID orgId, String url, HttpMethod method,
                                         Map<String, Object> payload) {
        // Authoritative SSRF gate: validate the fully-composed URL immediately
        // before the RestTemplate call, closing the window even if a bad setting
        // was written by some other path.
        com.katasticho.erp.common.net.OutboundUrlGuard.validate(url, "GSP_URL");
        Map<String, String> s = orgSettingsService.getAll(orgId);
        HttpHeaders headers = new HttpHeaders();
        if (payload != null) headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(s.getOrDefault(TOKEN, ""));
        if (notBlank(s.get(GSTIN))) headers.set("gstin", s.get(GSTIN).trim());

        try {
            @SuppressWarnings("unchecked")
            ResponseEntity<Map> resp = gspRestTemplate.exchange(
                    url, method, new HttpEntity<>(payload, headers), Map.class);
            if (!resp.getStatusCode().is2xxSuccessful() || resp.getBody() == null) {
                throw new BusinessException(
                        "GSP returned " + resp.getStatusCode() + " with no usable body",
                        "GSP_BAD_RESPONSE", HttpStatus.BAD_GATEWAY);
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> body = resp.getBody();
            return body;
        } catch (RestClientException e) {
            log.warn("GSP {} call to {} failed for org {}: {}", method, url, orgId, e.getMessage());
            throw new BusinessException(
                    "Could not reach the GSP: " + e.getMessage(),
                    "GSP_UNREACHABLE", HttpStatus.BAD_GATEWAY);
        }
    }

    private Map<String, Object> get(UUID orgId, String url) {
        com.katasticho.erp.common.net.OutboundUrlGuard.validate(url, "GSP_URL");
        Map<String, String> s = orgSettingsService.getAll(orgId);
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(s.getOrDefault(TOKEN, ""));
        if (notBlank(s.get(GSTIN))) headers.set("gstin", s.get(GSTIN).trim());

        try {
            @SuppressWarnings("unchecked")
            ResponseEntity<Map> resp = gspRestTemplate.exchange(
                    url, org.springframework.http.HttpMethod.GET,
                    new HttpEntity<>(headers), Map.class);
            if (!resp.getStatusCode().is2xxSuccessful() || resp.getBody() == null) {
                throw new BusinessException(
                        "GSP returned " + resp.getStatusCode() + " with no usable body",
                        "GSP_BAD_RESPONSE", HttpStatus.BAD_GATEWAY);
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> body = resp.getBody();
            return body;
        } catch (RestClientException e) {
            log.warn("GSP GET {} failed for org {}: {}", url, orgId, e.getMessage());
            throw new BusinessException(
                    "Could not reach the GSP: " + e.getMessage(),
                    "GSP_UNREACHABLE", HttpStatus.BAD_GATEWAY);
        }
    }

    private String path(UUID orgId, String key, String fallback) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        String base = s.getOrDefault(BASE_URL, "").trim();
        if (base.endsWith("/")) base = base.substring(0, base.length() - 1);
        String p = s.getOrDefault(key, fallback);
        if (p == null || p.isBlank()) p = fallback;
        if (!p.startsWith("/")) p = "/" + p;
        return base + p;
    }

    private static boolean notBlank(String v) {
        return v != null && !v.isBlank();
    }
}
