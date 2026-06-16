package com.katasticho.erp.amortization.controller;

import com.katasticho.erp.amortization.entity.AmortizationSchedule;
import com.katasticho.erp.amortization.service.AmortizationService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Recurring amortization schedules — prepaids, deferred income, accruals.
 * The period run posts the recognition journal to the GL.
 */
@RestController
@RequestMapping("/api/v1/amortization")
@RequiredArgsConstructor
public class AmortizationController {

    private final AmortizationService service;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<AmortizationSchedule>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(service.list()));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AmortizationSchedule>> create(@RequestBody Map<String, Object> b) {
        AmortizationSchedule s = AmortizationSchedule.builder()
                .scheduleType((String) b.get("scheduleType"))
                .description((String) b.get("description"))
                .reference((String) b.get("reference"))
                .totalAmount(num(b.get("totalAmount")))
                .startYear(Integer.parseInt(b.get("startYear").toString()))
                .startMonth(Integer.parseInt(b.get("startMonth").toString()))
                .numberOfPeriods(Integer.parseInt(b.get("numberOfPeriods").toString()))
                .debitAccountCode((String) b.get("debitAccountCode"))
                .creditAccountCode((String) b.get("creditAccountCode"))
                .notes((String) b.get("notes"))
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.create(s), "Schedule created"));
    }

    @PostMapping("/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> run(
            @RequestParam int year, @RequestParam int month) {
        return ResponseEntity.ok(ApiResponse.ok(service.run(year, month), "Amortization posted"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AmortizationSchedule>> cancel(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.cancel(id), "Schedule cancelled"));
    }

    private static BigDecimal num(Object o) {
        return o == null ? BigDecimal.ZERO : new BigDecimal(o.toString());
    }
}
