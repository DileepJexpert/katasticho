package com.katasticho.erp.pricing.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.pricing.dto.SchemeRequest;
import com.katasticho.erp.pricing.dto.SchemeResponse;
import com.katasticho.erp.pricing.service.SchemeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/schemes")
@RequiredArgsConstructor
public class SchemeController {

    private final SchemeService schemeService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<SchemeResponse>> create(
            @Valid @RequestBody SchemeRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(schemeService.create(request)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<SchemeResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody SchemeRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(schemeService.update(id, request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        schemeService.delete(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<SchemeResponse>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(schemeService.list()));
    }

    @GetMapping("/applicable")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<SchemeResponse>>> applicable(
            @RequestParam UUID itemId,
            @RequestParam(required = false) BigDecimal quantity) {
        return ResponseEntity.ok(ApiResponse.ok(schemeService.getApplicable(itemId, quantity)));
    }
}
