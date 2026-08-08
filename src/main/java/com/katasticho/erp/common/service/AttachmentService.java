package com.katasticho.erp.common.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.repository.EntityAttachmentRepository;
import com.katasticho.erp.common.service.storage.AttachmentStorage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AttachmentService {

    private final EntityAttachmentRepository attachmentRepository;
    private final AttachmentStorage storage;
    private final AttachmentAccessPolicy accessPolicy;

    @Transactional
    public EntityAttachment upload(String entityType, UUID entityId, MultipartFile file) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        accessPolicy.assertCanUpload(entityType, entityId);

        String fileName  = file.getOriginalFilename() != null ? file.getOriginalFilename() : "file";
        String fileId    = UUID.randomUUID().toString();
        String extension = fileName.contains(".") ? fileName.substring(fileName.lastIndexOf('.')) : "";
        String storedName = fileId + extension;

        String relativePath = orgId + "/" + entityType + "/" + entityId + "/" + storedName;
        storage.store(relativePath, file);

        String fileUrl = "/" + relativePath;

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
        accessPolicy.assertCanRead(entityType, entityId);
        return attachmentRepository.findByOrgIdAndEntityTypeAndEntityIdAndDeletedFalse(
                orgId, entityType, entityId);
    }

    /**
     * Fetch the stored file body for an org-scoped attachment — the read half
     * that never existed (uploads previously had no download endpoint at all).
     */
    @Transactional(readOnly = true)
    public StoredFile download(UUID attachmentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EntityAttachment attachment = attachmentRepository.findByIdAndOrgId(attachmentId, orgId)
                .filter(a -> !a.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("Attachment", attachmentId));
        accessPolicy.assertCanRead(attachment.getEntityType(), attachment.getEntityId());
        String relativePath = attachment.getFileUrl().startsWith("/")
                ? attachment.getFileUrl().substring(1)
                : attachment.getFileUrl();
        return new StoredFile(attachment, storage.read(relativePath));
    }

    public record StoredFile(EntityAttachment attachment, byte[] content) {}

    @Transactional
    public void delete(UUID attachmentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EntityAttachment attachment = attachmentRepository.findByIdAndOrgId(attachmentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Attachment", attachmentId));
        accessPolicy.assertCanDelete(attachment.getEntityType(), attachment.getEntityId());
        attachment.setDeleted(true);
        attachmentRepository.save(attachment);
    }
}
