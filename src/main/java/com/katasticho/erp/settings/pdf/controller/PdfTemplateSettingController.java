package com.katasticho.erp.settings.pdf.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.settings.pdf.dto.PdfTemplateSettingRequest;
import com.katasticho.erp.settings.pdf.dto.PdfTemplateSettingResponse;
import com.katasticho.erp.settings.pdf.service.PdfTemplateSettingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/settings/pdf-templates")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
public class PdfTemplateSettingController {

    private final PdfTemplateSettingService service;

    @GetMapping
    public ApiResponse<List<PdfTemplateSettingResponse>> getAllTemplates() {
        return ApiResponse.ok(service.getAllSettings());
    }

    @GetMapping("/{documentType}")
    public ApiResponse<PdfTemplateSettingResponse> getTemplate(@PathVariable String documentType) {
        return ApiResponse.ok(service.getSetting(documentType));
    }

    @PostMapping
    public ApiResponse<PdfTemplateSettingResponse> saveTemplate(@Valid @RequestBody PdfTemplateSettingRequest request) {
        return ApiResponse.ok(service.saveOrUpdate(request));
    }
}