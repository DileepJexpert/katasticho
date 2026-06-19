package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.service.FssaiService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/fssai")
@RequiredArgsConstructor
public class FssaiController {

    private final FssaiService service;

    @GetMapping("/items/{itemId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Item>> getItemFssai(@PathVariable UUID itemId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getItemFssai(itemId)));
    }

    @PutMapping("/items/{itemId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<Item>> updateItemFssai(
            @PathVariable UUID itemId,
            @RequestBody FssaiService.FssaiUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.updateItemFssai(itemId, request),
                "FSSAI compliance fields updated"));
    }

    @GetMapping("/reports/allergen-exposure")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Item>>> allergenExposureReport(
            @RequestParam String allergen) {
        return ResponseEntity.ok(ApiResponse.ok(service.allergenExposureReport(allergen)));
    }

    @GetMapping("/reports/license-renewal")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> licenseRenewalReport(
            @RequestParam(defaultValue = "60") int daysAhead) {
        return ResponseEntity.ok(ApiResponse.ok(service.licenseRenewalReport(daysAhead)));
    }

    @GetMapping("/allergens")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<String>>> majorAllergens() {
        return ResponseEntity.ok(ApiResponse.ok(service.majorAllergens()));
    }
}
