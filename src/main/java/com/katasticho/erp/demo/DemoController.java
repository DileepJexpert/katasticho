package com.katasticho.erp.demo;

import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Demo data endpoints. Intended for onboarding, QA and dashboard screenshots;
 * writes go through {@link DemoSeedService} which is idempotent per-org.
 */
@RestController
@RequestMapping("/api/v1/demo")
@RequiredArgsConstructor
public class DemoController {

    private final DemoSeedService demoSeedService;

    @PostMapping("/seed-sharma-medical")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<DemoSeedService.DemoSeedResult>> seedSharmaMedical() {
        return ResponseEntity.ok(ApiResponse.ok(demoSeedService.seedSharmaMedical()));
    }
}
