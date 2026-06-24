package com.katasticho.erp.vat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

/**
 * UAE FTA VAT201 return generator — quarterly filing data for AE orgs.
 *
 * <p>Class-level {@code @RequiresCountry("AE")} keeps an Indian org from
 * accidentally seeing UAE VAT boxes for an INR P&amp;L. The Oman sibling at
 * {@code /api/v1/vat/oman/return} ({@link OmanVatReturnController}) runs the
 * same {@link VatReturnService#vatReturn} aggregator — both regulators share
 * a 5% flat regime + the cloned {@code AE→OM} CoA template (V15 migration).
 */
@RestController
@RequestMapping("/api/v1/vat/uae")
@RequiredArgsConstructor
@RequiresCountry("AE")
public class VatReturnController {

    private final VatReturnService vatReturnService;
    private final ObjectMapper objectMapper;

    /**
     * Generate the VAT201 box rollups for a date window.
     *
     * @param fromDate inclusive start (typically quarter start, e.g. {@code 2026-04-01})
     * @param toDate   inclusive end   (quarter end, e.g. {@code 2026-06-30})
     */
    @GetMapping("/return")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VatReturnService.VatReturn>> uaeReturn(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(ApiResponse.ok(vatReturnService.vatReturn(fromDate, toDate)));
    }

    /**
     * Download the same VAT201 box rollups as a pretty-printed JSON file. The
     * accountant copies the box totals into the EmaraTax portal and attaches
     * the JSON to their internal filing record. Mirrors {@code GstController.exportGstr3b}.
     */
    @GetMapping("/return/export")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportUaeReturn(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) throws Exception {
        VatReturnService.VatReturn data = vatReturnService.vatReturn(fromDate, toDate);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        String filename = String.format("VAT201_AE_%s_%s.json", fromDate, toDate);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }
}
