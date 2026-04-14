package com.katasticho.erp.common.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.service.AttachmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/attachments")
@RequiredArgsConstructor
public class AttachmentController {

    private final AttachmentService attachmentService;

    @PostMapping("/{entityType}/{entityId}")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<EntityAttachment> upload(
            @PathVariable String entityType,
            @PathVariable UUID entityId,
            @RequestParam("file") MultipartFile file) {
        return ApiResponse.created(attachmentService.upload(entityType, entityId, file));
    }

    @GetMapping("/{entityType}/{entityId}")
    public ApiResponse<List<EntityAttachment>> list(
            @PathVariable String entityType,
            @PathVariable UUID entityId) {
        return ApiResponse.ok(attachmentService.list(entityType, entityId));
    }

    @DeleteMapping("/{attachmentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID attachmentId) {
        attachmentService.delete(attachmentId);
    }
}
