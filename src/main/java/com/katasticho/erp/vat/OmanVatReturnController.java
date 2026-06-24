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
 * Oman Tax Authority (OTA) VAT return generator — quarterly filing data for
 * OM orgs.
 *
 * <p>Oman introduced 5% VAT in April 2021, mirroring the GCC VAT Framework
 * Agreement that UAE adopted in 2018. The box semantics are identical
 * (standard-rated supplies → output VAT, standard-rated expenses →
 * recoverable input VAT, net payable = output − input), only the OTA's box
 * numbering differs from the FTA's — the JSON returned uses the regulator-
 * neutral {@code box1a/1b/9/10/14} keys from {@link VatReturnService.VatReturn},
 * and the accountant maps them to the OTA form on submission.
 *
 * <p>Same {@link VatReturnService} aggregator as the UAE controller — V15
 * cloned the Gulf TRADING CoA from AE to OM, so 2041 (VAT Output) and 1511
 * (VAT Input) are the same accounts in both countries. Class-level
 * {@code @RequiresCountry("OM")} keeps a non-Oman org from accidentally
 * seeing OMR VAT boxes.
 */
@RestController
@RequestMapping("/api/v1/vat/oman")
@RequiredArgsConstructor
@RequiresCountry("OM")
public class OmanVatReturnController {

    private final VatReturnService vatReturnService;
    private final ObjectMapper objectMapper;

    /**
     * Generate the Oman VAT return box rollups for a date window.
     *
     * @param fromDate inclusive start (typically quarter start, e.g. {@code 2026-04-01})
     * @param toDate   inclusive end   (quarter end, e.g. {@code 2026-06-30})
     */
    @GetMapping("/return")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VatReturnService.VatReturn>> omanReturn(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(ApiResponse.ok(vatReturnService.vatReturn(fromDate, toDate)));
    }

    /**
     * Download the same box rollups as a pretty-printed JSON file for OTA
     * eFiling reference. Mirror of the UAE {@code /return/export} endpoint.
     */
    @GetMapping("/return/export")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportOmanReturn(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) throws Exception {
        VatReturnService.VatReturn data = vatReturnService.vatReturn(fromDate, toDate);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        String filename = String.format("VAT_OM_%s_%s.json", fromDate, toDate);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }
}
