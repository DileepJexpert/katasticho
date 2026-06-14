package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.hr.entity.EmployeeDocument;
import com.katasticho.erp.hr.repository.EmployeeDocumentRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EmployeeDocumentServiceTest {

    @Mock private EmployeeDocumentRepository repo;
    @Mock private AttachmentService attachmentService;
    private EmployeeDocumentService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new EmployeeDocumentService(repo, attachmentService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void upload_storesMetadataAndAttachmentRef() {
        UUID attId = UUID.randomUUID();
        MultipartFile file = mock(MultipartFile.class);
        EntityAttachment att = mock(EntityAttachment.class);
        when(att.getId()).thenReturn(attId);
        when(att.getFileName()).thenReturn("pan.pdf");
        when(att.getFileType()).thenReturn("application/pdf");
        when(att.getFileSize()).thenReturn(1234L);
        when(att.getFileUrl()).thenReturn("/org/EMPLOYEE/u/pan.pdf");
        when(attachmentService.upload("EMPLOYEE", userId, file)).thenReturn(att);
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        EmployeeDocument doc = service.upload(
                userId, "pan", "PAN Card", LocalDate.of(2030, 1, 1), file);

        assertEquals("PAN", doc.getCategory());
        assertEquals("PAN Card", doc.getTitle());
        assertEquals(attId, doc.getAttachmentId());
        assertEquals("pan.pdf", doc.getFileName());
        assertEquals(1234L, doc.getFileSize());
        assertEquals(LocalDate.of(2030, 1, 1), doc.getExpiryDate());
        assertEquals(userId, doc.getEmployeeUserId());
    }

    @Test
    void delete_byOwner_softDeletesAndRemovesFile() {
        UUID docId = UUID.randomUUID();
        UUID attId = UUID.randomUUID();
        EmployeeDocument doc = EmployeeDocument.builder()
                .id(docId).orgId(orgId).employeeUserId(userId).title("x")
                .attachmentId(attId).build();
        when(repo.findByIdAndOrgIdAndIsDeletedFalse(docId, orgId)).thenReturn(Optional.of(doc));
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        service.delete(docId);

        assertTrue(doc.isDeleted());
        verify(attachmentService).delete(attId);
    }

    @Test
    void delete_byNonOwnerNonAdmin_throws() {
        UUID docId = UUID.randomUUID();
        EmployeeDocument doc = EmployeeDocument.builder()
                .id(docId).orgId(orgId).employeeUserId(UUID.randomUUID()).title("x").build();
        when(repo.findByIdAndOrgIdAndIsDeletedFalse(docId, orgId)).thenReturn(Optional.of(doc));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.delete(docId));
        assertEquals("HR_DOC_FORBIDDEN", ex.getErrorCode());
        verify(attachmentService, never()).delete(any());
    }

    @Test
    void delete_byAdmin_succeeds() {
        TenantContext.setCurrentRole("ADMIN");
        UUID docId = UUID.randomUUID();
        EmployeeDocument doc = EmployeeDocument.builder()
                .id(docId).orgId(orgId).employeeUserId(UUID.randomUUID()).title("x").build();
        when(repo.findByIdAndOrgIdAndIsDeletedFalse(docId, orgId)).thenReturn(Optional.of(doc));
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        service.delete(docId);

        assertTrue(doc.isDeleted());
        verify(repo).save(eq(doc));
    }
}
