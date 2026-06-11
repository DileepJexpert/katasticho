package com.katasticho.erp.notification.whatsapp;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link WhatsAppService} — the pure phone normalisation and the
 * "not configured → fail result (never throws)" contract. Live provider HTTP is
 * out of scope for a unit test.
 */
class WhatsAppServiceTest {

    private final OrgSettingsService settings = mock(OrgSettingsService.class);
    private final WhatsAppService service = new WhatsAppService(settings, new ObjectMapper());

    @Test
    void toWhatsAppNumber_normalisesIndianMobiles() {
        assertThat(WhatsAppService.toWhatsAppNumber("9876543210")).isEqualTo("919876543210");
        assertThat(WhatsAppService.toWhatsAppNumber("098765 43210")).isEqualTo("919876543210");
        assertThat(WhatsAppService.toWhatsAppNumber("+91 98765-43210")).isEqualTo("919876543210");
        assertThat(WhatsAppService.toWhatsAppNumber("919876543210")).isEqualTo("919876543210");
        assertThat(WhatsAppService.toWhatsAppNumber("12345")).isNull();
        assertThat(WhatsAppService.toWhatsAppNumber(null)).isNull();
    }

    @Test
    void sendTemplate_withoutApiKey_failsWithoutThrowing() {
        UUID orgId = UUID.randomUUID();
        when(settings.get(eq(orgId), eq("whatsapp.provider"), any())).thenReturn("META");
        when(settings.get(eq(orgId), eq("whatsapp.api_key"), any())).thenReturn(null);
        when(settings.get(eq(orgId), eq("whatsapp.lang"), any())).thenReturn("en");

        WhatsAppService.SendResult r = service.sendTemplate(
                orgId, "919876543210", "invoice_doc", List.of("A", "B"), null, null);

        assertThat(r.ok()).isFalse();
        assertThat(r.error()).contains("api_key not configured");
    }

    @Test
    void sendTemplate_withoutRecipient_failsWithoutThrowing() {
        UUID orgId = UUID.randomUUID();
        when(settings.get(eq(orgId), eq("whatsapp.provider"), any())).thenReturn("META");
        when(settings.get(eq(orgId), eq("whatsapp.api_key"), any())).thenReturn("tok");
        when(settings.get(eq(orgId), eq("whatsapp.lang"), any())).thenReturn("en");

        WhatsAppService.SendResult r = service.sendTemplate(
                orgId, null, "invoice_doc", List.of("A"), null, null);

        assertThat(r.ok()).isFalse();
        assertThat(r.error()).contains("no valid WhatsApp number");
    }
}
