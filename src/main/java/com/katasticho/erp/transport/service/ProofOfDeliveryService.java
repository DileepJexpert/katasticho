package com.katasticho.erp.transport.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.transport.dto.FleetDtos.*;
import com.katasticho.erp.transport.entity.ProofOfDelivery;
import com.katasticho.erp.transport.repository.ProofOfDeliveryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Proof of delivery — recipient + GPS + signature/photo evidence against a
 * dispatched consignment. Files (signature image, parcel photos) are stored via
 * the shared {@link AttachmentService} under {@code entityType='POD'}, so POD
 * reuses real file storage rather than inventing its own.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProofOfDeliveryService {

    static final String ATTACHMENT_ENTITY = "POD";

    private final ProofOfDeliveryRepository repository;
    private final AttachmentService attachmentService;

    @Transactional
    public PodResponse create(CreatePodRequest req) {
        UUID orgId = requireOrgId();
        if (req.deliveryChallanId() == null && req.courierShipmentId() == null
                && req.invoiceId() == null) {
            throw new BusinessException(
                    "Link the POD to a delivery challan, courier shipment, or invoice",
                    "POD_NO_LINK", HttpStatus.BAD_REQUEST);
        }
        ProofOfDelivery pod = ProofOfDelivery.builder()
                .deliveryChallanId(req.deliveryChallanId())
                .courierShipmentId(req.courierShipmentId())
                .invoiceId(req.invoiceId())
                .contactId(req.contactId())
                .recipientName(req.recipientName())
                .recipientPhone(req.recipientPhone())
                .deliveredAt(req.deliveredAt() != null ? req.deliveredAt() : Instant.now())
                .geoLatitude(req.geoLatitude())
                .geoLongitude(req.geoLongitude())
                .notes(req.notes())
                .build();
        pod.setOrgId(orgId);
        pod = repository.save(pod);
        log.info("POD {} recorded (challan={}, recipient={}) for org {}",
                pod.getId(), pod.getDeliveryChallanId(), pod.getRecipientName(), orgId);
        return toResponse(pod);
    }

    /** Attach a signature/photo to an existing POD. */
    @Transactional
    public PodResponse attach(UUID podId, MultipartFile file) {
        ProofOfDelivery pod = require(podId);
        attachmentService.upload(ATTACHMENT_ENTITY, pod.getId(), file);
        return toResponse(pod);
    }

    @Transactional(readOnly = true)
    public PodResponse get(UUID id) {
        return toResponse(require(id));
    }

    @Transactional(readOnly = true)
    public List<PodResponse> list(UUID deliveryChallanId) {
        UUID orgId = requireOrgId();
        List<ProofOfDelivery> rows = deliveryChallanId == null
                ? repository.findByOrgIdAndIsDeletedFalseOrderByDeliveredAtDesc(orgId)
                : repository.findByOrgIdAndDeliveryChallanIdAndIsDeletedFalseOrderByDeliveredAtDesc(
                        orgId, deliveryChallanId);
        return rows.stream().map(this::toResponse).toList();
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private ProofOfDelivery require(UUID id) {
        return repository.findByIdAndOrgIdAndIsDeletedFalse(id, requireOrgId())
                .orElseThrow(() -> new BusinessException(
                        "Proof of delivery not found", "POD_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    private PodResponse toResponse(ProofOfDelivery pod) {
        List<PodAttachment> atts = attachmentService.list(ATTACHMENT_ENTITY, pod.getId()).stream()
                .map(this::toAttachment).toList();
        return new PodResponse(pod.getId(), pod.getDeliveryChallanId(), pod.getCourierShipmentId(),
                pod.getInvoiceId(), pod.getContactId(), pod.getRecipientName(), pod.getRecipientPhone(),
                pod.getDeliveredAt(), pod.getGeoLatitude(), pod.getGeoLongitude(), pod.getNotes(), atts);
    }

    private PodAttachment toAttachment(EntityAttachment a) {
        return new PodAttachment(a.getId(), a.getFileName(), a.getFileUrl(), a.getFileSize());
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
