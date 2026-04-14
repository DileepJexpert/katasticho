package com.katasticho.erp.common.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.repository.EntityAttachmentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AttachmentService {

    private final EntityAttachmentRepository attachmentRepository;

    @Value("${app.attachment.storage-path:./attachments}")
    private String storagePath;

    @Transactional
    public EntityAttachment upload(String entityType, UUID entityId, MultipartFile file) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        String fileName  = file.getOriginalFilename() != null ? file.getOriginalFilename() : "file";
        String fileId    = UUID.randomUUID().toString();
        String extension = fileName.contains(".") ? fileName.substring(fileName.lastIndexOf('.')) : "";
        String storedName = fileId + extension;

        Path dir = Paths.get(storagePath, orgId.toString(), entityType, entityId.toString());
        try {
            Files.createDirectories(dir);
            file.transferTo(dir.resolve(storedName));
        } catch (IOException e) {
            log.error("Failed to store attachment: {}", e.getMessage());
            throw new BusinessException("Failed to store file: " + e.getMessage(),
                    "ATTACHMENT_STORE_FAILED", HttpStatus.INTERNAL_SERVER_ERROR);
        }

        String fileUrl = "/" + orgId + "/" + entityType + "/" + entityId + "/" + storedName;

        EntityAttachment attachment = EntityAttachment.builder()
                .orgId(orgId)
                .entityType(entityType)
                .entityId(entityId)
                .fileName(fileName)
                .fileType(file.getContentType())
                .fileSize(file.getSize())
                .fileUrl(fileUrl)
                .uploadedBy(userId)
                .build();

        return attachmentRepository.save(attachment);
    }

    @Transactional(readOnly = true)
    public List<EntityAttachment> list(String entityType, UUID entityId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return attachmentRepository.findByOrgIdAndEntityTypeAndEntityIdAndDeletedFalse(
                orgId, entityType, entityId);
    }

    @Transactional
    public void delete(UUID attachmentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EntityAttachment attachment = attachmentRepository.findByIdAndOrgId(attachmentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Attachment", attachmentId));
        attachment.setDeleted(true);
        attachmentRepository.save(attachment);
    }
}
