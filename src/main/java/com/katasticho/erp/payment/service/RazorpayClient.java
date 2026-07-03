package com.katasticho.erp.payment.service;

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

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Razorpay Payment Links client — config-inert (does nothing until an org sets
 * its keys), mirroring {@code GspClient}/{@code CourierClient}: per-org creds in
 * {@code org_settings}, an {@link #isConfigured} gate, masked {@link #settings},
 * the shared {@code gspRestTemplate} bean, and tolerant response parsing.
 *
 * <p>Razorpay authenticates the API with HTTP Basic (key_id : key_secret) and
 * signs webhooks with HMAC-SHA256 over the raw body keyed by the webhook secret.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RazorpayClient {

    public static final String PROVIDER = "RAZORPAY";
    public static final String ENABLED = "payments.razorpay.enabled";
    public static final String KEY_ID = "payments.razorpay.key_id";
    public static final String KEY_SECRET = "payments.razorpay.key_secret";
    public static final String WEBHOOK_SECRET = "payments.razorpay.webhook_secret";
    public static final String BASE_URL = "payments.razorpay.base_url";
    public static final String WEBHOOK_TOKEN = "payments.razorpay.webhook_token";
    private static final String DEFAULT_BASE = "https://api.razorpay.com";

    private final RestTemplate gspRestTemplate;
    private final OrgSettingsService orgSettingsService;

    /** A link can be created only when the org has enabled Razorpay + set keys. */
    public boolean isConfigured(UUID orgId) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        return "true".equalsIgnoreCase(s.getOrDefault(ENABLED, "false"))
                && notBlank(s.get(KEY_ID))
                && notBlank(s.get(KEY_SECRET));
    }

    /**
     * Create a hosted payment link. {@code amountPaise} is Razorpay's integer
     * minor-unit amount. Returns the parsed {@code {id, short_url, status}}.
     */
    public Map<String, Object> createPaymentLink(UUID orgId, long amountPaise, String currency,
                                                 String referenceId, String description,
                                                 String customerName, String customerEmail,
                                                 String customerContact) {
        if (!isConfigured(orgId)) {
            throw new BusinessException(
                    "Razorpay is not configured — set your key id + secret in payment settings.",
                    "RAZORPAY_NOT_CONFIGURED", HttpStatus.BAD_REQUEST);
        }
        Map<String, String> s = orgSettingsService.getAll(orgId);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("amount", amountPaise);
        body.put("currency", currency);
        body.put("reference_id", referenceId);
        body.put("description", description);
        body.put("reminder_enable", true);
        Map<String, Object> customer = new LinkedHashMap<>();
        if (notBlank(customerName)) customer.put("name", customerName);
        if (notBlank(customerEmail)) customer.put("email", customerEmail);
        if (notBlank(customerContact)) customer.put("contact", customerContact);
        if (!customer.isEmpty()) body.put("customer", customer);
        Map<String, Object> notify = new LinkedHashMap<>();
        notify.put("sms", notBlank(customerContact));
        notify.put("email", notBlank(customerEmail));
        body.put("notify", notify);

        String url = base(s) + "/v1/payment_links";
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBasicAuth(s.get(KEY_ID).trim(), s.get(KEY_SECRET).trim());

        try {
            @SuppressWarnings("rawtypes")
            ResponseEntity<Map> resp = gspRestTemplate.exchange(
                    url, HttpMethod.POST, new HttpEntity<>(body, headers), Map.class);
            if (resp.getBody() == null) {
                throw new BusinessException("Razorpay returned an empty response",
                        "RAZORPAY_BAD_RESPONSE", HttpStatus.BAD_GATEWAY);
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> out = resp.getBody();
            return out;
        } catch (BusinessException e) {
            throw e;
        } catch (RestClientException e) {
            log.warn("Razorpay createPaymentLink failed for org {}: {}", orgId, e.getMessage());
            throw new BusinessException("Could not reach Razorpay: " + e.getMessage(),
                    "RAZORPAY_UNREACHABLE", HttpStatus.BAD_GATEWAY);
        }
    }

    /**
     * Timing-safe HMAC-SHA256 verification of a Razorpay webhook. The HMAC MUST
     * be computed over the RAW request body bytes (never a re-serialized DTO).
     * Uses the org's own webhook secret — each tenant has its own Razorpay
     * account, so the org must be resolved (from the URL path token) first.
     */
    public boolean verifyWebhookSignature(UUID orgId, String rawBody, String signatureHeader) {
        String secret = orgSettingsService.getAll(orgId).get(WEBHOOK_SECRET);
        if (!notBlank(secret) || !notBlank(signatureHeader) || rawBody == null) {
            return false;
        }
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.trim().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(rawBody.getBytes(StandardCharsets.UTF_8));
            String computed = hexEncode(hash);
            return MessageDigest.isEqual(
                    computed.getBytes(StandardCharsets.UTF_8),
                    signatureHeader.trim().toLowerCase().getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            log.warn("Razorpay signature verification error for org {}: {}", orgId, e.getMessage());
            return false;
        }
    }

    /** Mint/persist the per-org webhook path token used to resolve the org (no JWT). */
    public String ensureWebhookToken(UUID orgId) {
        String existing = orgSettingsService.getAll(orgId).get(WEBHOOK_TOKEN);
        if (notBlank(existing)) return existing;
        String token = "rzpwh_" + UUID.randomUUID().toString().replace("-", "");
        orgSettingsService.set(orgId, WEBHOOK_TOKEN, token);
        return token;
    }

    /** Settings for the UI; secrets are never echoed — only a "set" boolean. */
    public Map<String, Object> settings(UUID orgId) {
        Map<String, String> s = orgSettingsService.getAll(orgId);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("enabled", "true".equalsIgnoreCase(s.getOrDefault(ENABLED, "false")));
        out.put("keyId", s.getOrDefault(KEY_ID, ""));
        out.put("baseUrl", s.getOrDefault(BASE_URL, DEFAULT_BASE));
        out.put("keySecretSet", notBlank(s.get(KEY_SECRET)));
        out.put("webhookSecretSet", notBlank(s.get(WEBHOOK_SECRET)));
        out.put("webhookToken", s.getOrDefault(WEBHOOK_TOKEN, ""));
        return out;
    }

    private static String base(Map<String, String> s) {
        String base = s.getOrDefault(BASE_URL, DEFAULT_BASE).trim();
        if (base.isEmpty()) base = DEFAULT_BASE;
        return base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
    }

    private static String hexEncode(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(Character.forDigit((b >> 4) & 0xF, 16));
            sb.append(Character.forDigit(b & 0xF, 16));
        }
        return sb.toString();
    }

    private static boolean notBlank(String v) {
        return v != null && !v.isBlank();
    }
}
