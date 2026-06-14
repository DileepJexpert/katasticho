package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.hr.entity.EmployeeDocument;
import com.katasticho.erp.hr.repository.EmployeeDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * HR Employee Document management — Core HR module 7. Stores employee documents
 * (ID/PAN/insurance/contract) with category + expiry, reusing the shared
 * {@link AttachmentService} for the actual file storage.
 */
@Service
@RequiredArgsConstructor
public class EmployeeDocumentService {

    private final EmployeeDocumentRepository repository;
    private final AttachmentService attachmentService;

    @Transactional
    public EmployeeDocument upload(UUID employeeUserId, String category, String title,
                                   LocalDate expiryDate, MultipartFile file) {
        if (title == null || title.isBlank()) {
            throw new BusinessException("Document title is required",
                    "HR_DOC_NO_TITLE", HttpStatus.BAD_REQUEST);
        }
        EntityAttachment att = attachmentService.upload("EMPLOYEE", employeeUserId, file);
        return repository.save(EmployeeDocument.builder()
                .orgId(TenantContext.getCurrentOrgId())
                .employeeUserId(employeeUserId)
                .category(category != null && !category.isBlank() ? category.trim().toUpperCase() : "OTHER")
                .title(title.trim())
                .fileName(att.getFileName())
                .fileUrl(att.getFileUrl())
                .fileType(att.getFileType())
                .fileSize(att.getFileSize())
                .expiryDate(expiryDate)
                .attachmentId(att.getId())
                .uploadedBy(TenantContext.getCurrentUserId())
                .build());
    }

    @Transactional(readOnly = true)
    public List<EmployeeDocument> listForEmployee(UUID employeeUserId) {
        return repository.findByOrgIdAndEmployeeUserIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), employeeUserId);
    }

    @Transactional(readOnly = true)
    public List<EmployeeDocument> myDocuments() {
        return listForEmployee(TenantContext.getCurrentUserId());
    }

    /** Documents expiring on or before today + days — the HR renewal watchlist. */
    @Transactional(readOnly = true)
    public List<EmployeeDocument> expiring(int days) {
        return repository.findByOrgIdAndExpiryDateLessThanEqualAndIsDeletedFalseOrderByExpiryDateAsc(
                TenantContext.getCurrentOrgId(), LocalDate.now().plusDays(days));
    }

    @Transactional
    public void delete(UUID id) {
        EmployeeDocument doc = repository
                .findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("EmployeeDocument", id));
        boolean owner = doc.getEmployeeUserId().equals(TenantContext.getCurrentUserId());
        if (!owner && !isAdmin()) {
            throw new BusinessException("Only the owner or HR can delete this document",
                    "HR_DOC_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
        doc.setDeleted(true);
        repository.save(doc);
        if (doc.getAttachmentId() != null) {
            attachmentService.delete(doc.getAttachmentId());
        }
    }

    private static boolean isAdmin() {
        String role = TenantContext.getCurrentRole();
        return role != null && (role.contains("OWNER") || role.contains("ADMIN"));
    }
}
