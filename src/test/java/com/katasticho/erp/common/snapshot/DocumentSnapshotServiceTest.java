package com.katasticho.erp.common.snapshot;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DocumentSnapshotServiceTest {

    @Mock
    private PostedDocumentSnapshotRepository snapshotRepository;

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void createSnapshotStoresCanonicalHashAndPayload() {
        UUID orgId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        UUID documentId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        DocumentSnapshotService service = new DocumentSnapshotService(snapshotRepository, objectMapper());
        when(snapshotRepository.findByOrgIdAndDocumentTypeAndDocumentId(orgId, "INVOICE", documentId))
                .thenReturn(Optional.empty());
        when(snapshotRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        PostedDocumentSnapshot snapshot = service.createSnapshot(
                "INVOICE",
                documentId,
                "INV-1",
                Map.of("total", new BigDecimal("1180.00"), "status", "SENT"));

        assertThat(snapshot.getOrgId()).isEqualTo(orgId);
        assertThat(snapshot.getPostedBy()).isEqualTo(userId);
        assertThat(snapshot.getDocumentNumber()).isEqualTo("INV-1");
        assertThat(snapshot.getSnapshotJson()).containsEntry("status", "SENT");
        assertThat(snapshot.getSnapshotHash()).hasSize(64);

        ArgumentCaptor<PostedDocumentSnapshot> captor = ArgumentCaptor.forClass(PostedDocumentSnapshot.class);
        verify(snapshotRepository).save(captor.capture());
        assertThat(captor.getValue().getDocumentType()).isEqualTo("INVOICE");
    }

    @Test
    void createSnapshotReturnsExistingSnapshotForSameDocument() {
        UUID orgId = UUID.randomUUID();
        UUID documentId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        PostedDocumentSnapshot existing = PostedDocumentSnapshot.builder()
                .orgId(orgId)
                .documentType("INVOICE")
                .documentId(documentId)
                .documentNumber("INV-1")
                .snapshotJson(Map.of("status", "SENT"))
                .snapshotHash("abc")
                .build();

        DocumentSnapshotService service = new DocumentSnapshotService(snapshotRepository, objectMapper());
        when(snapshotRepository.findByOrgIdAndDocumentTypeAndDocumentId(orgId, "INVOICE", documentId))
                .thenReturn(Optional.of(existing));

        PostedDocumentSnapshot snapshot = service.createSnapshot("INVOICE", documentId, "INV-1", Map.of());

        assertThat(snapshot).isSameAs(existing);
        verify(snapshotRepository, never()).save(any());
    }

    private ObjectMapper objectMapper() {
        return new ObjectMapper().registerModule(new JavaTimeModule());
    }
}
