package com.katasticho.erp.customfield.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.customfield.dto.*;
import com.katasticho.erp.customfield.service.CustomFieldService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/custom-fields")
@RequiredArgsConstructor
public class CustomFieldController {

    private final CustomFieldService customFieldService;

    @GetMapping("/definitions")
    public ApiResponse<List<CustomFieldDefinitionResponse>> getDefinitions(
            @RequestParam String entityType,
            @RequestParam(defaultValue = "true") boolean activeOnly
    ) {
        return ApiResponse.ok(customFieldService.getDefinitions(entityType, activeOnly));
    }

    @GetMapping("/definitions/all")
    public ApiResponse<List<CustomFieldDefinitionResponse>> getAllDefinitions() {
        return ApiResponse.ok(customFieldService.getAllDefinitions());
    }

    @PostMapping("/definitions")
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    public ResponseEntity<ApiResponse<CustomFieldDefinitionResponse>> createDefinition(
            @Valid @RequestBody CustomFieldDefinitionRequest req
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(customFieldService.createDefinition(req)));
    }

    @PutMapping("/definitions/{id}")
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    public ApiResponse<CustomFieldDefinitionResponse> updateDefinition(
            @PathVariable UUID id,
            @Valid @RequestBody CustomFieldDefinitionRequest req
    ) {
        return ApiResponse.ok(customFieldService.updateDefinition(id, req));
    }

    @DeleteMapping("/definitions/{id}")
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    public ApiResponse<Void> deleteDefinition(@PathVariable UUID id) {
        customFieldService.deleteDefinition(id);
        return ApiResponse.ok(null);
    }

    @GetMapping("/values/{entityType}/{entityId}")
    public ApiResponse<List<CustomFieldValueDTO>> getValues(
            @PathVariable String entityType,
            @PathVariable UUID entityId
    ) {
        return ApiResponse.ok(customFieldService.getValues(entityType, entityId));
    }

    @PostMapping("/values/{entityType}/{entityId}")
    public ApiResponse<List<CustomFieldValueDTO>> saveValues(
            @PathVariable String entityType,
            @PathVariable UUID entityId,
            @RequestBody SaveCustomFieldValuesRequest req
    ) {
        return ApiResponse.ok(customFieldService.saveValues(entityType, entityId, req.values()));
    }

    @PostMapping("/values/{entityType}/batch")
    public ApiResponse<Map<UUID, List<CustomFieldValueDTO>>> getValuesBatch(
            @PathVariable String entityType,
            @RequestBody List<UUID> entityIds
    ) {
        return ApiResponse.ok(customFieldService.getValuesBatch(entityType, entityIds));
    }
}
