package com.katasticho.erp.vat;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
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
 * accidentally seeing UAE VAT boxes for an INR P&amp;L. Oman has an analogous
 * 5% VAT return that will mount under {@code /api/v1/vat/oman/return} when the
 * Oman expansion lands.
 */
@RestController
@RequestMapping("/api/v1/vat/uae")
@RequiredArgsConstructor
@RequiresCountry("AE")
public class VatReturnController {

    private final VatReturnService vatReturnService;

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
        return ResponseEntity.ok(ApiResponse.ok(vatReturnService.uaeReturn(fromDate, toDate)));
    }
}
