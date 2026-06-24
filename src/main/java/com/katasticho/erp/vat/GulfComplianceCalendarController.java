package com.katasticho.erp.vat;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * Read-only compliance calendar for AE/OM orgs — quarterly VAT return
 * deadline plus any pending end-of-service gratuity payouts. Mirrors the
 * India-only {@code /api/v1/gst/compliance-calendar} so the Gulf dashboard
 * has the same "what's due, when" surface.
 */
@RestController
@RequestMapping("/api/v1/vat/compliance-calendar")
@RequiredArgsConstructor
@RequiresCountry({"AE", "OM"})
public class GulfComplianceCalendarController {

    private final GulfComplianceCalendarService calendarService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> calendar() {
        return ResponseEntity.ok(ApiResponse.ok(calendarService.calendar()));
    }
}
