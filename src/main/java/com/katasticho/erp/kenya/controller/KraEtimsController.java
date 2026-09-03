package com.katasticho.erp.kenya.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.kenya.dto.KraEtimsInvoiceResponse;
import com.katasticho.erp.kenya.dto.KraEtimsSubmitRequest;
import com.katasticho.erp.kenya.service.KraEtimsService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/kenya/etims")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR')")
public class KraEtimsController {

    private final KraEtimsService service;

    @GetMapping("/submissions")
    public ApiResponse<List<KraEtimsInvoiceResponse>> listSubmissions() {
        return ApiResponse.ok(service.listSubmissions());
    }

    @PostMapping("/submit")
    public ApiResponse<KraEtimsInvoiceResponse> submitToEtims(
            @Valid @RequestBody KraEtimsSubmitRequest request) {
        return ApiResponse.ok(service.submitToEtims(request));
    }
}