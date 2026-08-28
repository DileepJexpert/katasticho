package com.katasticho.erp.notification.whatsapp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Provider-agnostic WhatsApp Business send service for templated documents.
 * Mirrors {@link com.katasticho.erp.notification.sms.SmsService}: per-org config
 * in {@code org_settings}, native {@link HttpClient}, failures logged not thrown.
 *
 * <p>Two providers:
 * <ul>
 *   <li><b>META</b> — WhatsApp Cloud API. A PDF is uploaded as media (no public
 *       URL needed), then a pre-approved template is sent with a document
 *       header referencing the media id, plus body text parameters.</li>
 *   <li><b>CUSTOM</b> — POST a normalised JSON (to, template, params, base64
 *       document) to an aggregator webhook ({@code whatsapp.custom_url}).</li>
 * </ul>
 *
 * <p>Settings keys: {@code whatsapp.enabled, whatsapp.provider, whatsapp.api_key,
 * whatsapp.phone_number_id, whatsapp.custom_url, whatsapp.lang}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WhatsAppService {

    private final OrgSettingsService settingsService;
    private final ObjectMapper objectMapper;

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(8))
            .build();
    private static final String GRAPH = "https://graph.facebook.com/v20.0";

    /** Outcome of a send attempt; never throws so callers can record it. */
    public record SendResult(boolean ok, String provider, String messageId, String error) {
        static SendResult ok(String provider, String messageId) {
            return new SendResult(true, provider, messageId, null);
        }
        static SendResult fail(String provider, String error) {
            return new SendResult(false, provider, null, error);
        }
    }

    public boolean isEnabled(UUID orgId) {
        return "true".equalsIgnoreCase(settingsService.get(orgId, "whatsapp.enabled", "false"));
    }

    public String provider(UUID orgId) {
        return settingsService.get(orgId, "whatsapp.provider", "META");
    }

    /**
     * Send a template message, optionally with a PDF document header. Blocking;
     * callers that want fire-and-forget should wrap in a CompletableFuture.
     */
    public SendResult sendTemplate(UUID orgId, String e164Phone, String templateName,
                                   List<String> bodyParams, byte[] pdf, String filename) {
        String provider = provider(orgId);
        String apiKey = settingsService.get(orgId, "whatsapp.api_key", null);
        String lang = settingsService.get(orgId, "whatsapp.lang", "en");
        if (apiKey == null || apiKey.isBlank()) {
            return SendResult.fail(provider, "whatsapp.api_key not configured");
        }
        if (e164Phone == null) {
            return SendResult.fail(provider, "recipient has no valid WhatsApp number");
        }
        try {
            if ("CUSTOM".equalsIgnoreCase(provider)) {
                return sendCustom(orgId, apiKey, e164Phone, templateName, lang, bodyParams, pdf, filename);
            }
            return sendMeta(orgId, apiKey, e164Phone, templateName, lang, bodyParams, pdf, filename);
        } catch (Exception e) {
            log.warn("[WhatsApp] send to {} via {} failed: {}", e164Phone, provider, e.getMessage());
            return SendResult.fail(provider, e.getMessage());
        }
    }

    /**
     * Send a raw interactive/conversational text message (for bot replies & customer Q&A).
     */
    public SendResult sendTextMessage(UUID orgId, String e164Phone, String text) {
        String provider = provider(orgId);
        String apiKey = settingsService.get(orgId, "whatsapp.api_key", null);
        if (e164Phone == null || e164Phone.isBlank()) {
            return SendResult.fail(provider, "recipient has no valid WhatsApp number");
        }
        if (text == null || text.isBlank()) {
            return SendResult.fail(provider, "message text is empty");
        }
        if (apiKey == null || apiKey.isBlank()) {
            String simId = "wamid_sim_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
            log.info("[WhatsApp Bot Sandbox] To: {} | Msg: {}", e164Phone, text.replace("\n", " \\n "));
            return SendResult.ok("SANDBOX", simId);
        }
        try {
            if ("CUSTOM".equalsIgnoreCase(provider)) {
                return sendCustomText(orgId, apiKey, e164Phone, text);
            }
            return sendMetaText(orgId, apiKey, e164Phone, text);
        } catch (Exception e) {
            log.warn("[WhatsApp] send text to {} via {} failed: {}", e164Phone, provider, e.getMessage());
            return SendResult.fail(provider, e.getMessage());
        }
    }

    // ── META (WhatsApp Cloud API) ─────────────────────────────────────────

    private SendResult sendMeta(UUID orgId, String token, String to, String template, String lang,
                                List<String> bodyParams, byte[] pdf, String filename) throws Exception {
        String phoneNumberId = settingsService.get(orgId, "whatsapp.phone_number_id", null);
        if (phoneNumberId == null || phoneNumberId.isBlank()) {
            return SendResult.fail("META", "whatsapp.phone_number_id not configured");
        }

        String mediaId = null;
        if (pdf != null && pdf.length > 0) {
            mediaId = metaUploadMedia(phoneNumberId, token, pdf, filename);
        }

        ObjectNode root = objectMapper.createObjectNode();
        root.put("messaging_product", "whatsapp");
        root.put("to", to);
        root.put("type", "template");
        ObjectNode tmpl = root.putObject("template");
        tmpl.put("name", template);
        tmpl.putObject("language").put("code", lang);
        ArrayNode components = tmpl.putArray("components");

        if (mediaId != null) {
            ObjectNode header = components.addObject();
            header.put("type", "header");
            ArrayNode params = header.putArray("parameters");
            ObjectNode docParam = params.addObject();
            docParam.put("type", "document");
            ObjectNode doc = docParam.putObject("document");
            doc.put("id", mediaId);
            doc.put("filename", filename);
        }
        if (bodyParams != null && !bodyParams.isEmpty()) {
            ObjectNode body = components.addObject();
            body.put("type", "body");
            ArrayNode params = body.putArray("parameters");
            for (String p : bodyParams) {
                params.addObject().put("type", "text").put("text", p == null ? "" : p);
            }
        }

        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(GRAPH + "/" + phoneNumberId + "/messages"))
                .header("Authorization", "Bearer " + token)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(root)))
                .timeout(Duration.ofSeconds(20))
                .build();
        HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() / 100 != 2) {
            // Status only — don't reflect the raw upstream body into the stored result
            // (mirrors the CUSTOM branch; avoids leaking provider error detail).
            return SendResult.fail("META", "HTTP " + resp.statusCode());
        }
        JsonNode node = objectMapper.readTree(resp.body());
        String msgId = node.path("messages").path(0).path("id").asText(null);
        return SendResult.ok("META", msgId);
    }

    /** Upload a PDF to the Cloud API media endpoint; returns the media id. */
    private String metaUploadMedia(String phoneNumberId, String token, byte[] pdf, String filename) throws Exception {
        String boundary = "----katasticho" + UUID.randomUUID().toString().replace("-", "");
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        writePart(body, boundary, "messaging_product", "whatsapp");
        // File part.
        body.write(("--" + boundary + "\r\n").getBytes(StandardCharsets.UTF_8));
        body.write(("Content-Disposition: form-data; name=\"file\"; filename=\"" + filename + "\"\r\n")
                .getBytes(StandardCharsets.UTF_8));
        body.write("Content-Type: application/pdf\r\n\r\n".getBytes(StandardCharsets.UTF_8));
        body.write(pdf);
        body.write("\r\n".getBytes(StandardCharsets.UTF_8));
        writePart(body, boundary, "type", "application/pdf");
        body.write(("--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8));

        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(GRAPH + "/" + phoneNumberId + "/media"))
                .header("Authorization", "Bearer " + token)
                .header("Content-Type", "multipart/form-data; boundary=" + boundary)
                .POST(HttpRequest.BodyPublishers.ofByteArray(body.toByteArray()))
                .timeout(Duration.ofSeconds(25))
                .build();
        HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() / 100 != 2) {
            throw new RuntimeException("media upload HTTP " + resp.statusCode() + ": " + resp.body());
        }
        String id = objectMapper.readTree(resp.body()).path("id").asText(null);
        if (id == null || id.isBlank()) {
            throw new RuntimeException("media upload returned no id: " + resp.body());
        }
        return id;
    }

    private static void writePart(ByteArrayOutputStream out, String boundary, String name, String value)
            throws java.io.IOException {
        out.write(("--" + boundary + "\r\n").getBytes(StandardCharsets.UTF_8));
        out.write(("Content-Disposition: form-data; name=\"" + name + "\"\r\n\r\n")
                .getBytes(StandardCharsets.UTF_8));
        out.write((value + "\r\n").getBytes(StandardCharsets.UTF_8));
    }

    // ── CUSTOM (aggregator webhook) ───────────────────────────────────────

    private SendResult sendCustom(UUID orgId, String apiKey, String to, String template, String lang,
                                  List<String> bodyParams, byte[] pdf, String filename) throws Exception {
        String url = settingsService.get(orgId, "whatsapp.custom_url", null);
        if (url == null || url.isBlank()) {
            return SendResult.fail("CUSTOM", "whatsapp.custom_url not configured");
        }
        // SSRF guard: this URL is an org-admin-writable setting, so an internal /
        // loopback / metadata host must be refused before the server-side POST.
        // sendTemplate wraps this in try/catch → a blocked URL becomes a FAILED row.
        com.katasticho.erp.common.net.OutboundUrlGuard.validate(url, "WHATSAPP_URL");
        ObjectNode root = objectMapper.createObjectNode();
        root.put("to", to);
        root.put("template", template);
        root.put("language", lang);
        root.set("params", objectMapper.valueToTree(bodyParams == null ? List.of() : bodyParams));
        if (pdf != null && pdf.length > 0) {
            root.put("documentBase64", Base64.getEncoder().encodeToString(pdf));
            root.put("filename", filename);
        }
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(root)))
                .timeout(Duration.ofSeconds(20))
                .build();
        HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() / 100 != 2) {
            // Status only — never reflect the raw response body into the readable
            // message log (an internal endpoint's body would otherwise leak there).
            return SendResult.fail("CUSTOM", "HTTP " + resp.statusCode());
        }
        JsonNode node = safeTree(resp.body());
        String msgId = node == null ? null
                : firstText(node, "messageId", "message_id", "id");
        return SendResult.ok("CUSTOM", msgId);
    }

    private SendResult sendMetaText(UUID orgId, String token, String to, String text) throws Exception {
        String phoneNumberId = settingsService.get(orgId, "whatsapp.phone_number_id", null);
        if (phoneNumberId == null || phoneNumberId.isBlank()) {
            return SendResult.fail("META", "whatsapp.phone_number_id not configured");
        }
        ObjectNode root = objectMapper.createObjectNode();
        root.put("messaging_product", "whatsapp");
        root.put("to", to);
        root.put("type", "text");
        root.putObject("text").put("body", text);

        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(GRAPH + "/" + phoneNumberId + "/messages"))
                .header("Authorization", "Bearer " + token)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(root)))
                .timeout(Duration.ofSeconds(15))
                .build();
        HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() / 100 != 2) {
            return SendResult.fail("META", "HTTP " + resp.statusCode());
        }
        JsonNode node = objectMapper.readTree(resp.body());
        String msgId = node.path("messages").path(0).path("id").asText(null);
        return SendResult.ok("META", msgId);
    }

    private SendResult sendCustomText(UUID orgId, String apiKey, String to, String text) throws Exception {
        String url = settingsService.get(orgId, "whatsapp.custom_url", null);
        if (url == null || url.isBlank()) {
            return SendResult.fail("CUSTOM", "whatsapp.custom_url not configured");
        }
        com.katasticho.erp.common.net.OutboundUrlGuard.validate(url, "WHATSAPP_URL");
        ObjectNode root = objectMapper.createObjectNode();
        root.put("to", to);
        root.put("message", text);
        root.put("type", "text");

        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(root)))
                .timeout(Duration.ofSeconds(15))
                .build();
        HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() / 100 != 2) {
            return SendResult.fail("CUSTOM", "HTTP " + resp.statusCode());
        }
        JsonNode node = safeTree(resp.body());
        String msgId = node == null ? null : firstText(node, "messageId", "message_id", "id");
        return SendResult.ok("CUSTOM", msgId);
    }

    private JsonNode safeTree(String body) {
        try {
            return objectMapper.readTree(body);
        } catch (Exception e) {
            return null;
        }
    }

    private static String firstText(JsonNode node, String... keys) {
        for (String k : keys) {
            JsonNode v = node.get(k);
            if (v != null && !v.asText("").isBlank()) return v.asText();
        }
        return null;
    }

    /**
     * Normalise an Indian phone to WhatsApp E.164-without-plus (91XXXXXXXXXX).
     * Returns null when no usable number can be derived.
     */
    public static String toWhatsAppNumber(String raw) {
        if (raw == null) return null;
        String digits = raw.replaceAll("[^0-9]", "");
        if (digits.length() == 12 && digits.startsWith("91")) return digits;
        if (digits.length() == 11 && digits.startsWith("0")) digits = digits.substring(1);
        if (digits.length() == 10 && digits.charAt(0) >= '6') return "91" + digits;
        if (digits.length() > 12) return digits; // already an international number
        return null;
    }

    /** Settings for the UI; the api key/token is masked. */
    public Map<String, Object> settings(UUID orgId) {
        var s = settingsService.getAll(orgId);
        return Map.of(
                "enabled", "true".equalsIgnoreCase(s.getOrDefault("whatsapp.enabled", "false")),
                "provider", s.getOrDefault("whatsapp.provider", "META"),
                "phoneNumberId", s.getOrDefault("whatsapp.phone_number_id", ""),
                "customUrl", s.getOrDefault("whatsapp.custom_url", ""),
                "lang", s.getOrDefault("whatsapp.lang", "en"),
                "autoSendReceipt", "true".equalsIgnoreCase(s.getOrDefault("whatsapp.auto_send_receipt", "false")),
                "apiKeySet", s.getOrDefault("whatsapp.api_key", "").isBlank() ? false : true,
                "templateInvoice", s.getOrDefault("whatsapp.template_invoice", ""),
                "templateReceipt", s.getOrDefault("whatsapp.template_receipt", ""),
                "templateReminder", s.getOrDefault("whatsapp.template_reminder", ""));
    }
}
