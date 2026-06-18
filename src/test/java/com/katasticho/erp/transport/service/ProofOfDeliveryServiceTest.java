package com.katasticho.erp.transport.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.transport.dto.FleetDtos.*;
import com.katasticho.erp.transport.entity.ProofOfDelivery;
import com.katasticho.erp.transport.repository.ProofOfDeliveryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.mock.web.MockMultipartFile;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ProofOfDeliveryServiceTest {

    @Mock private ProofOfDeliveryRepository repository;
    @Mock private AttachmentService attachmentService;
    private ProofOfDeliveryService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID challanId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ProofOfDeliveryService(repository, attachmentService);
        TenantContext.setCurrentOrgId(orgId);
        when(repository.save(any(ProofOfDelivery.class))).thenAnswer(inv -> {
            ProofOfDelivery p = inv.getArgument(0);
            if (p.getId() == null) p.setId(UUID.randomUUID());
            return p;
        });
        when(attachmentService.list(eq("POD"), any())).thenReturn(List.of());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private CreatePodRequest req(UUID challan) {
        return new CreatePodRequest(challan, null, null, null,
                "Ramesh", "9811111111", null, null, null, "Left at gate");
    }

    @Test
    void create_requiresAtLeastOneLink() {
        assertThatThrownBy(() -> service.create(req(null)))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("POD_NO_LINK");
    }

    @Test
    void create_recordsRecipientAndDefaultsDeliveredAt() {
        PodResponse r = service.create(req(challanId));

        assertThat(r.recipientName()).isEqualTo("Ramesh");
        assertThat(r.deliveryChallanId()).isEqualTo(challanId);
        assertThat(r.deliveredAt()).isNotNull(); // defaulted to now
        assertThat(r.attachments()).isEmpty();
    }

    @Test
    void attach_storesViaAttachmentServiceUnderPodEntity() {
        ProofOfDelivery pod = ProofOfDelivery.builder().deliveryChallanId(challanId).build();
        pod.setId(UUID.randomUUID());
        pod.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(pod.getId(), orgId))
                .thenReturn(Optional.of(pod));
        EntityAttachment att = EntityAttachment.builder()
                .id(UUID.randomUUID()).fileName("sign.png").fileUrl("/x/sign.png").fileSize(1234L).build();
        when(attachmentService.list("POD", pod.getId())).thenReturn(List.of(att));

        var file = new MockMultipartFile("file", "sign.png", "image/png", new byte[]{1, 2, 3});
        PodResponse r = service.attach(pod.getId(), file);

        verify(attachmentService).upload("POD", pod.getId(), file);
        assertThat(r.attachments()).hasSize(1);
        assertThat(r.attachments().get(0).fileName()).isEqualTo("sign.png");
    }
}
