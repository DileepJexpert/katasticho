package com.katasticho.erp.kenya.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.kenya.dto.KenyaPayeCalculationRequest;
import com.katasticho.erp.kenya.dto.KenyaPayeCalculationResponse;
import com.katasticho.erp.kenya.service.KenyaPayeCalculatorService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/kenya/paye")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR', 'VIEWER')")
public class KenyaPayeController {

    private final KenyaPayeCalculatorService service;

    @PostMapping("/calculate")
    public ApiResponse<KenyaPayeCalculationResponse> calculate(@Valid @RequestBody KenyaPayeCalculationRequest request) {
        return ApiResponse.ok(service.calculate(request));
    }
}