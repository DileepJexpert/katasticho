package com.katasticho.erp.notification.whatsapp;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Public webhook endpoint for inbound WhatsApp messages and status callbacks.
 * Authenticated per-org via secret token in URL path.
 */
@RestController
@RequestMapping("/api/v1/whatsapp/webhook")
@RequiredArgsConstructor
@Slf4j
public class WhatsAppWebhookController {

    private final WhatsAppBotService botService;

    /**
     * Meta Cloud API Webhook Handshake Verification.
     */
    @GetMapping(value = "/{token}", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> verifyWebhook(
            @PathVariable String token,
            @RequestParam(name = "hub.mode", required = false) String mode,
            @RequestParam(name = "hub.verify_token", required = false) String verifyToken,
            @RequestParam(name = "hub.challenge", required = false) String challenge) {

        log.info("[WhatsApp Webhook] Verification attempt token={}, mode={}", token, mode);
        boolean verified = botService.verifyWebhookHandshake(token, mode, verifyToken, challenge);
        if (verified) {
            return ResponseEntity.ok(challenge);
        }
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Verification failed");
    }

    /**
     * Inbound message & event notification receiver.
     */
    @PostMapping(value = "/{token}", consumes = {MediaType.APPLICATION_JSON_VALUE, MediaType.TEXT_PLAIN_VALUE, "*/*"})
    public ResponseEntity<Map<String, Object>> receiveWebhook(
            @PathVariable String token,
            @RequestHeader(value = "X-Hub-Signature-256", required = false) String signatureHeader,
            @RequestBody String rawBody) {

        boolean processed = botService.processInboundWebhook(token, rawBody, signatureHeader);
        if (!processed) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("status", "REJECTED"));
        }
        return ResponseEntity.ok(Map.of("status", "PROCESSED"));
    }
}
