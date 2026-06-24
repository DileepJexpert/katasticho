package com.katasticho.erp.pharma.register;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * Statutory pharma register endpoints — Schedule H1 / Schedule X / Narcotics.
 *
 * <p>India-only ({@link RequiresCountry @RequiresCountry("IN")}) — the underlying
 * Drugs & Cosmetics Rules + NDPS Act 1985 are Indian statute. Other countries
 * (Gulf, Africa) have parallel regimes that will need separate gating.
 */
@RestController
@RequestMapping("/api/v1/pharma/statutory-registers")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
@RequiresCountry("IN")
public class StatutoryRegisterController {

    private final StatutoryRegisterService service;

    /** Paginated list of register entries, newest sale-date first. */
    @GetMapping
    public ResponseEntity<ApiResponse<Page<StatutoryRegisterEntry>>> list(
            @RequestParam("type") String type,
            @RequestParam(value = "from", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(value = "to", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "50") int size) {
        RegisterType registerType = parseType(type);
        Page<StatutoryRegisterEntry> p = service.list(
                registerType, from, to, PageRequest.of(page, Math.min(size, 500)));
        return ResponseEntity.ok(ApiResponse.ok(p));
    }

    /** Single entry by id. */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<StatutoryRegisterEntry>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    /**
     * CSV export for inspector visits. Streams an {@code application/csv}
     * download with all rows in the date range — paging deliberately not
     * applied here (the inspector wants the full register, not page 1 of 10).
     */
    @GetMapping("/export")
    public ResponseEntity<byte[]> export(
            @RequestParam("type") String type,
            @RequestParam(value = "from", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(value = "to", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        RegisterType registerType = parseType(type);
        byte[] body = service.exportCsv(registerType, from, to);
        String filename = String.format(Locale.ROOT, "statutory-register-%s-%s.csv",
                registerType.name().toLowerCase(Locale.ROOT),
                LocalDate.now());
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv"))
                .body(body);
    }

    /** Counts + retention warnings for the register dashboard tile. */
    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<Map<String, Object>>> dashboard(@RequestParam("type") String type) {
        RegisterType registerType = parseType(type);
        return ResponseEntity.ok(ApiResponse.ok(service.dashboard(registerType)));
    }

    private static RegisterType parseType(String raw) {
        if (raw == null) {
            throw new com.katasticho.erp.common.exception.BusinessException(
                    "Query parameter 'type' is required (H1 | SCHEDULE_X | NARCOTICS).",
                    "SREG_TYPE_REQUIRED");
        }
        try {
            return RegisterType.valueOf(raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException ex) {
            throw new com.katasticho.erp.common.exception.BusinessException(
                    "Unknown register type: " + raw + " (must be H1, SCHEDULE_X or NARCOTICS).",
                    "SREG_TYPE_INVALID");
        }
    }
}
