package com.katasticho.erp.sales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.sales.entity.ProofOfDelivery;
import com.katasticho.erp.sales.repository.ProofOfDeliveryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProofOfDeliveryServiceTest {

    @Mock private ProofOfDeliveryRepository repository;
    @Mock private AttachmentService attachmentService;
    private ProofOfDeliveryService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ProofOfDeliveryService(repository, attachmentService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    // ───── record ─────

    @Test
    void record_persistsOrgAndRecordedBy_andDefaultsDeliveredAt() {
        when(repository.save(any(ProofOfDelivery.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        UUID dcId = UUID.randomUUID();
        ProofOfDelivery input = ProofOfDelivery.builder()
                .deliveryChallanId(dcId)
                .recipientName("Ravi")
                .build();

        ProofOfDelivery saved = service.record(input);

        ArgumentCaptor<ProofOfDelivery> cap = ArgumentCaptor.forClass(ProofOfDelivery.class);
        verify(repository).save(cap.capture());
        ProofOfDelivery persisted = cap.getValue();

        assertEquals(orgId, persisted.getOrgId());
        assertEquals(userId, persisted.getRecordedBy());
        assertEquals(dcId, persisted.getDeliveryChallanId());
        assertFalse(persisted.isDeleted());
        assertNotNull(persisted.getDeliveredAt(), "deliveredAt should default when caller omits it");
        assertSame(persisted, saved);
    }

    @Test
    void record_requiresChallanOrInvoiceLink_throwsPodLinkRequired() {
        ProofOfDelivery input = ProofOfDelivery.builder()
                .recipientName("Ravi")
                .build();

        BusinessException ex = assertThrows(BusinessException.class, () -> service.record(input));
        assertEquals("POD_LINK_REQUIRED", ex.getErrorCode());
    }

    @Test
    void record_requiresRecipientName_throwsPodRecipientRequired() {
        ProofOfDelivery input = ProofOfDelivery.builder()
                .invoiceId(UUID.randomUUID())
                .build();

        BusinessException ex = assertThrows(BusinessException.class, () -> service.record(input));
        assertEquals("POD_RECIPIENT_REQUIRED", ex.getErrorCode());
    }

    @Test
    void record_preservesCallerSuppliedDeliveredAt() {
        when(repository.save(any(ProofOfDelivery.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        Instant explicit = Instant.parse("2026-06-15T10:30:00Z");

        ProofOfDelivery input = ProofOfDelivery.builder()
                .invoiceId(UUID.randomUUID())
                .recipientName("Ravi")
                .deliveredAt(explicit)
                .build();

        ProofOfDelivery saved = service.record(input);
        assertEquals(explicit, saved.getDeliveredAt());
    }

    // ───── delete ─────

    @Test
    void delete_softDeletes() {
        UUID id = UUID.randomUUID();
        ProofOfDelivery existing = ProofOfDelivery.builder()
                .invoiceId(UUID.randomUUID()).recipientName("X")
                .deliveredAt(Instant.now())
                .build();
        existing.setId(id);
        existing.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(existing));
        when(repository.save(any(ProofOfDelivery.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        service.delete(id);

        ArgumentCaptor<ProofOfDelivery> cap = ArgumentCaptor.forClass(ProofOfDelivery.class);
        verify(repository).save(cap.capture());
        assertTrue(cap.getValue().isDeleted());
    }

    // ───── attachments ─────

    @Test
    void attachFile_routesThroughAttachmentService_withPodEntityType() {
        UUID podId = UUID.randomUUID();
        ProofOfDelivery existing = ProofOfDelivery.builder()
                .invoiceId(UUID.randomUUID()).recipientName("X")
                .deliveredAt(Instant.now())
                .build();
        existing.setId(podId);
        existing.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(podId, orgId))
                .thenReturn(Optional.of(existing));

        MultipartFile file = mock(MultipartFile.class);
        EntityAttachment att = EntityAttachment.builder().fileName("signature.png").build();
        when(attachmentService.upload(eq("POD"), eq(podId), eq(file))).thenReturn(att);

        EntityAttachment result = service.attachFile(podId, file);

        assertSame(att, result);
        verify(attachmentService).upload("POD", podId, file);
    }

    @Test
    void attachFile_unknownPod_throws_notFound() {
        UUID podId = UUID.randomUUID();
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(podId, orgId))
                .thenReturn(Optional.empty());
        MultipartFile file = mock(MultipartFile.class);

        assertThrows(BusinessException.class, () -> service.attachFile(podId, file));
        verify(attachmentService, org.mockito.Mockito.never()).upload(any(), any(), any());
    }

    @Test
    void listAttachments_routesThroughAttachmentService() {
        UUID podId = UUID.randomUUID();
        ProofOfDelivery existing = ProofOfDelivery.builder()
                .invoiceId(UUID.randomUUID()).recipientName("X")
                .deliveredAt(Instant.now())
                .build();
        existing.setId(podId);
        existing.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(podId, orgId))
                .thenReturn(Optional.of(existing));
        when(attachmentService.list("POD", podId)).thenReturn(java.util.List.of());

        service.listAttachments(podId);

        verify(attachmentService).list("POD", podId);
    }
}
