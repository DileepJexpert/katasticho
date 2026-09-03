package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.dto.BarcodeLabelRequest;
import com.katasticho.erp.inventory.dto.BarcodeLabelResponse;
import com.katasticho.erp.inventory.service.ZplLabelGeneratorService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/inventory/barcode-labels")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR')")
public class BarcodeLabelController {

    private final ZplLabelGeneratorService zplService;

    @PostMapping("/generate")
    public ApiResponse<BarcodeLabelResponse> generateBarcodeLabel(@Valid @RequestBody BarcodeLabelRequest request) {
        return ApiResponse.ok(zplService.generateLabel(request));
    }
}