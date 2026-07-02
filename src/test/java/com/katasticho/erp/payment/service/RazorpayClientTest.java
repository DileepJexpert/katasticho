package com.katasticho.erp.payment.service;

import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class RazorpayClientTest {

    @Mock private OrgSettingsService orgSettingsService;
    private RazorpayClient client;
    private final UUID orgId = UUID.randomUUID();

    private RazorpayClient client() {
        return new RazorpayClient(null, orgSettingsService);
    }

    @Test
    void isConfigured_requires_enabled_plus_keys() {
        client = client();
        when(orgSettingsService.getAll(orgId)).thenReturn(Map.of(
                "payments.razorpay.enabled", "true",
                "payments.razorpay.key_id", "rzp_test_x",
                "payments.razorpay.key_secret", "secret"));
        assertThat(client.isConfigured(orgId)).isTrue();

        when(orgSettingsService.getAll(orgId)).thenReturn(Map.of(
                "payments.razorpay.enabled", "true",
                "payments.razorpay.key_id", "rzp_test_x")); // no secret
        assertThat(client.isConfigured(orgId)).isFalse();

        when(orgSettingsService.getAll(orgId)).thenReturn(Map.of()); // nothing
        assertThat(client.isConfigured(orgId)).isFalse();
    }

    @Test
    void settings_never_echoes_secrets() {
        client = client();
        when(orgSettingsService.getAll(orgId)).thenReturn(Map.of(
                "payments.razorpay.enabled", "true",
                "payments.razorpay.key_id", "rzp_test_x",
                "payments.razorpay.key_secret", "super-secret",
                "payments.razorpay.webhook_secret", "wh-secret"));

        Map<String, Object> s = client.settings(orgId);
        assertThat(s.get("keyId")).isEqualTo("rzp_test_x");
        assertThat(s.get("keySecretSet")).isEqualTo(true);
        assertThat(s.get("webhookSecretSet")).isEqualTo(true);
        assertThat(s).doesNotContainValue("super-secret");
        assertThat(s).doesNotContainValue("wh-secret");
    }

    @Test
    void verifyWebhookSignature_accepts_a_correct_hmac_and_rejects_tampering() throws Exception {
        client = client();
        String secret = "wh-secret-123";
        String body = "{\"event\":\"payment_link.paid\"}";
        when(orgSettingsService.getAll(orgId))
                .thenReturn(Map.of("payments.razorpay.webhook_secret", secret));

        String goodSig = hmac(secret, body);
        assertThat(client.verifyWebhookSignature(orgId, body, goodSig)).isTrue();
        // tampered body
        assertThat(client.verifyWebhookSignature(orgId, body + " ", goodSig)).isFalse();
        // wrong signature
        assertThat(client.verifyWebhookSignature(orgId, body, "deadbeef")).isFalse();
        // missing signature
        assertThat(client.verifyWebhookSignature(orgId, body, null)).isFalse();
    }

    @Test
    void verifyWebhookSignature_false_when_no_secret_set() {
        client = client();
        when(orgSettingsService.getAll(orgId)).thenReturn(Map.of());
        assertThat(client.verifyWebhookSignature(orgId, "{}", "anything")).isFalse();
    }

    @Test
    void ensureWebhookToken_mints_once_and_reuses() {
        client = client();
        when(orgSettingsService.getAll(orgId)).thenReturn(Map.of()); // none yet
        String minted = client.ensureWebhookToken(orgId);
        assertThat(minted).startsWith("rzpwh_");

        when(orgSettingsService.getAll(orgId))
                .thenReturn(Map.of("payments.razorpay.webhook_token", "rzpwh_existing"));
        assertThat(client.ensureWebhookToken(orgId)).isEqualTo("rzpwh_existing");
    }

    private static String hmac(String secret, String body) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        byte[] h = mac.doFinal(body.getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        for (byte b : h) sb.append(Character.forDigit((b >> 4) & 0xF, 16)).append(Character.forDigit(b & 0xF, 16));
        return sb.toString();
    }
}
