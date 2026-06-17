package com.katasticho.erp.courier.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Provider-agnostic courier-aggregator client — mirrors {@code GspClient}'s
 * shape exactly so it slots into the same operational pattern (per-org settings,
 * inert until credentials are filled in, manual fallback always available).
 *
 * <p>Supports each major Indian courier individually <em>or</em> a single
 * aggregator (Shiprocket / NimbusPost / iThink) that fans out to many.
 * Concretely: each partner has its own enable flag, base URL, and token under
 * {@code org_settings}; the methods here target the common REST shape (bearer
 * auth + JSON body) those aggregators present, not each NIC-style raw protocol.
 *
 * <p>Settings (per partner — example for BLUEDART):
 * <ul>
 *   <li>{@code courier.bluedart.enabled} — master switch</li>
 *   <li>{@code courier.bluedart.base_url}</li>
 *   <li>{@code courier.bluedart.token}</li>
 *   <li>{@code courier.bluedart.book_path} — defaults to {@code /shipments/book}</li>
 *   <li>{@code courier.bluedart.track_path} — defaults to {@code /shipments/track}</li>
 *   <li>{@code courier.bluedart.cod_remittance_path} — defaults to {@code /cod/remittances}</li>
 * </ul>
 * Same keys with {@code delhivery}, {@code india_post}, {@code dtdc}, {@code shiprocket}.
 *
 * <p>Manual AWB entry / manual remittance upload is the always-available
 * fallback — same operational fallback as the GSP manual portal upload.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CourierClient {

    public static final List<String> PARTNERS =
            List.of("BLUEDART", "DELHIVERY", "INDIA_POST", "DTDC", "SHIPROCKET", "OTHER");

    private final RestTemplate gspRestTemplate;   // reuse the existing pooled RestTemplate
    private final OrgSettingsService orgSettingsService;

    // ── Configuration ────────────────────────────────────────────────────

    public boolean isConfigured(UUID orgId, String partner) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        String prefix = prefix(partner);
        return "true".equalsIgnoreCase(s.getOrDefault(prefix + ".enabled", "false"))
                && notBlank(s.get(prefix + ".base_url"))
                && notBlank(s.get(prefix + ".token"));
    }

    /** Settings map for the UI; the token is masked (only its presence is exposed). */
    public Map<String, Object> settings(UUID orgId) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        Map<String, Object> out = new LinkedHashMap<>();
        for (String p : PARTNERS) {
            String prefix = prefix(p);
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("enabled", "true".equalsIgnoreCase(s.getOrDefault(prefix + ".enabled", "false")));
            row.put("baseUrl", s.getOrDefault(prefix + ".base_url", ""));
            row.put("bookPath", s.getOrDefault(prefix + ".book_path", ""));
            row.put("trackPath", s.getOrDefault(prefix + ".track_path", ""));
            row.put("codRemittancePath", s.getOrDefault(prefix + ".cod_remittance_path", ""));
            row.put("tokenSet", notBlank(s.get(prefix + ".token")));
            out.put(p, row);
        }
        return out;
    }

    public void updateSettings(UUID orgId, String partner, Map<String, String> body) {
        String prefix = prefix(partner);
        putIfPresent(orgId, body, "enabled", prefix + ".enabled");
        putIfPresent(orgId, body, "baseUrl", prefix + ".base_url");
        putIfPresent(orgId, body, "bookPath", prefix + ".book_path");
        putIfPresent(orgId, body, "trackPath", prefix + ".track_path");
        putIfPresent(orgId, body, "codRemittancePath", prefix + ".cod_remittance_path");
        if (body.get("token") != null && !body.get("token").isBlank()) {
            orgSettingsService.set(orgId, prefix + ".token", body.get("token").trim());
        }
    }

    /** Reachability probe — any HTTP status counts as reachable (mirrors GspClient.testConnection). */
    public Map<String, Object> testConnection(UUID orgId, String partner) {
        Map<String, Object> out = new LinkedHashMap<>();
        if (!isConfigured(orgId, partner)) {
            out.put("ok", false);
            out.put("reachable", false);
            out.put("message", "Enable the courier and set a base URL + token first.");
            return out;
        }
        Map<String, String> s = orgSettingsService.getAll(orgId);
        String base = s.getOrDefault(prefix(partner) + ".base_url", "").trim();
        if (base.endsWith("/")) base = base.substring(0, base.length() - 1);

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(s.getOrDefault(prefix(partner) + ".token", ""));
        try {
            ResponseEntity<String> resp = gspRestTemplate.exchange(
                    base, HttpMethod.GET, new HttpEntity<>(headers), String.class);
            return reachable(out, resp.getStatusCode().value());
        } catch (org.springframework.web.client.HttpStatusCodeException e) {
            return reachable(out, e.getStatusCode().value());
        } catch (RestClientException e) {
            log.warn("Courier {} test-connection failed for org {}: {}", partner, orgId, e.getMessage());
            out.put("ok", false);
            out.put("reachable", false);
            out.put("message", "Could not reach " + partner + ": " + e.getMessage());
            return out;
        }
    }

    // ── Operations ────────────────────────────────────────────────────────

    /** Book a parcel with the courier; returns the partner's response (typically an AWB). */
    public Map<String, Object> bookShipment(UUID orgId, String partner, Map<String, Object> payload) {
        return post(orgId, partner, path(orgId, partner, ".book_path", "/shipments/book"), payload);
    }

    /** Pull the latest status of an AWB (poll mode when the partner has no webhook). */
    public Map<String, Object> trackShipment(UUID orgId, String partner, String awbNumber) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        String url = path(orgId, partner, ".track_path", "/shipments/track")
                + (s.get(prefix(partner) + ".track_path") != null
                        && s.get(prefix(partner) + ".track_path").contains("?") ? "&" : "?")
                + "awb=" + awbNumber;
        return get(orgId, partner, url);
    }

    /** Pull a remittance file for a date — the source of the COD reconciliation loop. */
    public Map<String, Object> fetchCodRemittance(UUID orgId, String partner, String fromDate, String toDate) {
        String base = path(orgId, partner, ".cod_remittance_path", "/cod/remittances");
        String url = base + (base.contains("?") ? "&" : "?") + "from=" + fromDate + "&to=" + toDate;
        return get(orgId, partner, url);
    }

    // ── HTTP plumbing (mirrors GspClient.post/get) ───────────────────────

    private Map<String, Object> post(UUID orgId, String partner, String url, Map<String, Object> payload) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(s.getOrDefault(prefix(partner) + ".token", ""));
        try {
            @SuppressWarnings("unchecked")
            ResponseEntity<Map> resp = gspRestTemplate.postForEntity(
                    url, new HttpEntity<>(payload, headers), Map.class);
            if (!resp.getStatusCode().is2xxSuccessful() || resp.getBody() == null) {
                throw new BusinessException(
                        partner + " returned " + resp.getStatusCode() + " with no usable body",
                        "COURIER_BAD_RESPONSE", HttpStatus.BAD_GATEWAY);
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> body = resp.getBody();
            return body;
        } catch (RestClientException e) {
            log.warn("Courier {} POST {} failed for org {}: {}", partner, url, orgId, e.getMessage());
            throw new BusinessException(
                    "Could not reach " + partner + ": " + e.getMessage(),
                    "COURIER_UNREACHABLE", HttpStatus.BAD_GATEWAY);
        }
    }

    private Map<String, Object> get(UUID orgId, String partner, String url) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(s.getOrDefault(prefix(partner) + ".token", ""));
        try {
            @SuppressWarnings("unchecked")
            ResponseEntity<Map> resp = gspRestTemplate.exchange(
                    url, HttpMethod.GET, new HttpEntity<>(headers), Map.class);
            if (!resp.getStatusCode().is2xxSuccessful() || resp.getBody() == null) {
                throw new BusinessException(
                        partner + " returned " + resp.getStatusCode() + " with no usable body",
                        "COURIER_BAD_RESPONSE", HttpStatus.BAD_GATEWAY);
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> body = resp.getBody();
            return body;
        } catch (RestClientException e) {
            log.warn("Courier {} GET {} failed for org {}: {}", partner, url, orgId, e.getMessage());
            throw new BusinessException(
                    "Could not reach " + partner + ": " + e.getMessage(),
                    "COURIER_UNREACHABLE", HttpStatus.BAD_GATEWAY);
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private String path(UUID orgId, String partner, String key, String fallback) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        String base = s.getOrDefault(prefix(partner) + ".base_url", "").trim();
        if (base.endsWith("/")) base = base.substring(0, base.length() - 1);
        String p = s.getOrDefault(prefix(partner) + key, fallback);
        if (p == null || p.isBlank()) p = fallback;
        if (!p.startsWith("/")) p = "/" + p;
        return base + p;
    }

    private void putIfPresent(UUID orgId, Map<String, String> body, String field, String key) {
        if (body.containsKey(field)) {
            String v = body.get(field);
            orgSettingsService.set(orgId, key, v == null ? "" : v.trim());
        }
    }

    private Map<String, Object> reachable(Map<String, Object> out, int statusCode) {
        out.put("ok", true);
        out.put("reachable", true);
        out.put("statusCode", statusCode);
        out.put("message", "Courier host reachable (HTTP " + statusCode + ").");
        return out;
    }

    private String prefix(String partner) {
        String p = partner == null ? "" : partner.toLowerCase().replace('-', '_');
        if (!PARTNERS.contains(partner)) {
            throw new BusinessException(
                    "Unknown courier partner: " + partner + ". Known: " + PARTNERS,
                    "COURIER_BAD_PARTNER", HttpStatus.BAD_REQUEST);
        }
        return "courier." + p;
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }
}
