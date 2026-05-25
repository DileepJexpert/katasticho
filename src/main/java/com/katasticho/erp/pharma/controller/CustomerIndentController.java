package com.katasticho.erp.pharma.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.pharma.dto.CustomerIndentRequest;
import com.katasticho.erp.pharma.dto.CustomerIndentResponse;
import com.katasticho.erp.pharma.service.CustomerIndentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customer-indents")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
public class CustomerIndentController {

    private final CustomerIndentService indentService;

    @PostMapping
    public ResponseEntity<ApiResponse<CustomerIndentResponse>> create(
            @Valid @RequestBody CustomerIndentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(indentService.create(request)));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<CustomerIndentResponse>>> list(
            @RequestParam(required = false) String status,
            @PageableDefault(size = 30, sort = "createdAt") Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(indentService.list(status, pageable)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CustomerIndentResponse>> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(indentService.getById(id)));
    }

    @PostMapping("/{id}/status")
    public ResponseEntity<ApiResponse<CustomerIndentResponse>> updateStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                indentService.updateStatus(id, body.get("status")), "Indent status updated"));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> cancel(@PathVariable UUID id) {
        indentService.cancel(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Customer indent cancelled"));
    }
}
