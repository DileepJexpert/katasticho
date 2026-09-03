package com.katasticho.erp.inventory.putaway.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.putaway.dto.PutawayLineConfirmRequest;
import com.katasticho.erp.inventory.putaway.dto.PutawayTaskRequest;
import com.katasticho.erp.inventory.putaway.dto.PutawayTaskResponse;
import com.katasticho.erp.inventory.putaway.service.WarehousePutawayService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/putaway-tasks")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR')")
public class WarehousePutawayController {

    private final WarehousePutawayService service;

    @GetMapping
    public ApiResponse<List<PutawayTaskResponse>> listTasks(@RequestParam(required = false) String status) {
        return ApiResponse.ok(service.listTasks(status));
    }

    @GetMapping("/{id}")
    public ApiResponse<PutawayTaskResponse> getTask(@PathVariable UUID id) {
        return ApiResponse.ok(service.getTask(id));
    }

    @PostMapping
    public ApiResponse<PutawayTaskResponse> createTask(@Valid @RequestBody PutawayTaskRequest request) {
        return ApiResponse.ok(service.createTask(request));
    }

    @PostMapping("/{taskId}/lines/{lineId}/confirm")
    public ApiResponse<PutawayTaskResponse> confirmLine(
            @PathVariable UUID taskId,
            @PathVariable UUID lineId,
            @Valid @RequestBody PutawayLineConfirmRequest request) {
        return ApiResponse.ok(service.confirmLine(taskId, lineId, request));
    }

    @PostMapping("/{taskId}/cancel")
    public ApiResponse<PutawayTaskResponse> cancelTask(@PathVariable UUID taskId) {
        return ApiResponse.ok(service.cancelTask(taskId));
    }
}