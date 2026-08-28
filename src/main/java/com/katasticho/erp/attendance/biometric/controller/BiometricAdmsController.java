package com.katasticho.erp.attendance.biometric.controller;

import com.katasticho.erp.attendance.biometric.service.BiometricService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Public Cloud Push Receiver for ZKTeco / eSSL ADMS (Automatic Data Master Server) terminals.
 * Terminals periodically send HTTP GET / POST requests to `/iclock/cdata`.
 */
@RestController
@RequestMapping("/api/v1/biometric/adms")
@RequiredArgsConstructor
@Slf4j
public class BiometricAdmsController {

    private final BiometricService biometricService;

    /**
     * ADMS Handshake / Ping from biometric terminal.
     */
    @GetMapping(value = "/{token}/iclock/cdata", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> admsHandshake(
            @PathVariable String token,
            @RequestParam(name = "SN", required = false) String serialNumber) {
        log.info("[Biometric ADMS] Handshake from token={}, SN={}", token, serialNumber);
        return ResponseEntity.ok("GET OPTION FROM: " + (serialNumber != null ? serialNumber : "DEFAULT"));
    }

    /**
     * ADMS Attendance Log Push from biometric terminal.
     */
    @PostMapping(value = "/{token}/iclock/cdata", consumes = {MediaType.TEXT_PLAIN_VALUE, MediaType.APPLICATION_FORM_URLENCODED_VALUE, "*/*"})
    public ResponseEntity<String> receiveAdmsLogs(
            @PathVariable String token,
            @RequestParam(name = "SN", required = false) String serialNumber,
            @RequestBody(required = false) String body) {

        log.info("[Biometric ADMS] Push logs for token={}, SN={}, bytes={}", token, serialNumber, body != null ? body.length() : 0);
        var result = biometricService.parseAndIngestAdms(token, body != null ? body : "");
        log.info("[Biometric ADMS] Processed: {} logs (unmatched: {}, errors: {})",
                result.processed(), result.unmatched(), result.errors());

        // Standard ADMS protocol acknowledgment response
        return ResponseEntity.ok("OK: " + result.processed());
    }
}
