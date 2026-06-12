package com.katasticho.erp.notification.push;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.jsonwebtoken.Jwts;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.Map;

/**
 * Firebase Cloud Messaging (HTTP v1) client using a Google service-account,
 * without the Firebase Admin SDK: the OAuth2 assertion is signed locally
 * (RS256 via jjwt) and exchanged for an access token, which is cached until
 * shortly before expiry.
 *
 * Configure ONE of:
 *   app.push.fcm.service-account-file = /path/to/service-account.json
 *   app.push.fcm.service-account-json = {...raw JSON...}   (e.g. from env)
 *
 * When neither is set, {@link #isConfigured()} is false and callers fall
 * back to stub logging — existing behaviour unchanged.
 */
@Component
@Slf4j
public class FcmClient {

    private static final String SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    private final ObjectMapper mapper = new ObjectMapper();

    private final String serviceAccountFile;
    private final String serviceAccountJson;

    // Parsed lazily from the service account
    private volatile ServiceAccount account;
    private volatile String cachedToken;
    private volatile Instant cachedTokenExpiry = Instant.EPOCH;

    public FcmClient(
            @Value("${app.push.fcm.service-account-file:}") String serviceAccountFile,
            @Value("${app.push.fcm.service-account-json:}") String serviceAccountJson) {
        this.serviceAccountFile = serviceAccountFile;
        this.serviceAccountJson = serviceAccountJson;
    }

    public boolean isConfigured() {
        return !serviceAccountFile.isBlank() || !serviceAccountJson.isBlank();
    }

    /** Result of a single send attempt. */
    public enum SendResult { SENT, UNREGISTERED, FAILED }

    /**
     * Sends one notification to one device token. Never throws — push is
     * always best-effort. UNREGISTERED means the device token is dead and
     * should be deactivated by the caller.
     */
    public SendResult send(String deviceToken, String title, String body, Map<String, String> data) {
        try {
            ServiceAccount sa = serviceAccount();

            ObjectNode notification = mapper.createObjectNode();
            notification.put("title", title);
            notification.put("body", body);

            ObjectNode message = mapper.createObjectNode();
            message.put("token", deviceToken);
            message.set("notification", notification);
            if (data != null && !data.isEmpty()) {
                ObjectNode dataNode = mapper.createObjectNode();
                data.forEach(dataNode::put);
                message.set("data", dataNode);
            }
            ObjectNode payload = mapper.createObjectNode();
            payload.set("message", message);

            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create("https://fcm.googleapis.com/v1/projects/"
                            + sa.projectId() + "/messages:send"))
                    .header("Authorization", "Bearer " + accessToken(sa))
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(15))
                    .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload)))
                    .build();
            HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());

            if (resp.statusCode() / 100 == 2) {
                return SendResult.SENT;
            }
            // 404 NOT_FOUND / UNREGISTERED = stale token; tell caller to deactivate
            if (resp.statusCode() == 404 || resp.body().contains("UNREGISTERED")) {
                return SendResult.UNREGISTERED;
            }
            log.warn("FCM send failed ({}): {}", resp.statusCode(), truncate(resp.body()));
            return SendResult.FAILED;
        } catch (Exception e) {
            log.warn("FCM send error: {}", e.getMessage());
            return SendResult.FAILED;
        }
    }

    // ── OAuth2 service-account flow ──────────────────────────────────────

    private String accessToken(ServiceAccount sa) throws Exception {
        if (cachedToken != null && Instant.now().isBefore(cachedTokenExpiry)) {
            return cachedToken;
        }
        synchronized (this) {
            if (cachedToken != null && Instant.now().isBefore(cachedTokenExpiry)) {
                return cachedToken;
            }
            String assertion = buildAssertion(sa);
            String form = "grant_type=" + URLEncoder.encode(
                    "urn:ietf:params:oauth:grant-type:jwt-bearer", StandardCharsets.UTF_8)
                    + "&assertion=" + URLEncoder.encode(assertion, StandardCharsets.UTF_8);
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(sa.tokenUri()))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .timeout(Duration.ofSeconds(15))
                    .POST(HttpRequest.BodyPublishers.ofString(form))
                    .build();
            HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() / 100 != 2) {
                throw new IllegalStateException("FCM token exchange failed ("
                        + resp.statusCode() + "): " + truncate(resp.body()));
            }
            JsonNode node = mapper.readTree(resp.body());
            cachedToken = node.path("access_token").asText();
            long expiresIn = node.path("expires_in").asLong(3600);
            cachedTokenExpiry = Instant.now().plusSeconds(Math.max(60, expiresIn - 300));
            return cachedToken;
        }
    }

    /** RS256-signed OAuth2 JWT assertion for the service account. Package-private for tests. */
    String buildAssertion(ServiceAccount sa) {
        Instant now = Instant.now();
        return Jwts.builder()
                .issuer(sa.clientEmail())
                .audience().add(sa.tokenUri()).and()
                .claim("scope", SCOPE)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(3600)))
                .signWith(sa.privateKey(), Jwts.SIG.RS256)
                .compact();
    }

    ServiceAccount serviceAccount() throws Exception {
        ServiceAccount sa = account;
        if (sa != null) return sa;
        String json = !serviceAccountJson.isBlank()
                ? serviceAccountJson
                : Files.readString(Path.of(serviceAccountFile));
        sa = parseServiceAccount(json);
        account = sa;
        return sa;
    }

    /** Parses the Google service-account JSON. Package-private for tests. */
    ServiceAccount parseServiceAccount(String json) throws Exception {
        JsonNode node = mapper.readTree(json);
        String pem = node.path("private_key").asText();
        String base64 = pem
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
        PrivateKey key = KeyFactory.getInstance("RSA")
                .generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(base64)));
        return new ServiceAccount(
                node.path("project_id").asText(),
                node.path("client_email").asText(),
                node.path("token_uri").asText("https://oauth2.googleapis.com/token"),
                key);
    }

    record ServiceAccount(String projectId, String clientEmail, String tokenUri, PrivateKey privateKey) {}

    private static String truncate(String s) {
        return s != null && s.length() > 300 ? s.substring(0, 300) : s;
    }
}
