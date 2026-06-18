package com.katasticho.erp.sales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.sales.entity.ProofOfDelivery;
import com.katasticho.erp.sales.repository.ProofOfDeliveryRepository;
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
 * Records and reads Proof of Delivery rows. Signature and photo files are
 * delegated to {@link AttachmentService} with {@code entityType = "POD"}
 * so they sit in the same per-org storage layout as every other attachment
 * (vendor bills, employee documents, etc.) — single backup target, single
 * deletion policy.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProofOfDeliveryService {

    /** Attachment entityType key — keep stable, used by AttachmentService rows. */
    public static final String ATTACHMENT_ENTITY_TYPE = "POD";

    private final ProofOfDeliveryRepository repository;
    private final AttachmentService attachmentService;

    // ───────── CRUD ─────────

    @Transactional
    public ProofOfDelivery record(ProofOfDelivery input) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (input.getDeliveryChallanId() == null && input.getInvoiceId() == null) {
            throw new BusinessException(
                    "Proof of delivery must link to a delivery challan or an invoice",
                    "POD_LINK_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (input.getRecipientName() == null || input.getRecipientName().isBlank()) {
            throw new BusinessException(
                    "Recipient name is required",
                    "POD_RECIPIENT_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (input.getDeliveredAt() == null) {
            input.setDeliveredAt(Instant.now());
        }
        input.setOrgId(orgId);
        input.setId(null);
        input.setDeleted(false);
        input.setRecordedBy(TenantContext.getCurrentUserId());
        ProofOfDelivery saved = repository.save(input);
        log.info("POD recorded: {} (DC={}, invoice={}, recipient={})",
                saved.getId(), saved.getDeliveryChallanId(),
                saved.getInvoiceId(), saved.getRecipientName());
        return saved;
    }

    @Transactional(readOnly = true)
    public ProofOfDelivery get(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ProofOfDelivery", id));
    }

    @Transactional(readOnly = true)
    public List<ProofOfDelivery> listByChallan(UUID deliveryChallanId) {
        return repository.findByOrgIdAndDeliveryChallanIdAndIsDeletedFalseOrderByDeliveredAtDesc(
                TenantContext.getCurrentOrgId(), deliveryChallanId);
    }

    @Transactional(readOnly = true)
    public List<ProofOfDelivery> listByInvoice(UUID invoiceId) {
        return repository.findByOrgIdAndInvoiceIdAndIsDeletedFalseOrderByDeliveredAtDesc(
                TenantContext.getCurrentOrgId(), invoiceId);
    }

    @Transactional(readOnly = true)
    public List<ProofOfDelivery> listByContact(UUID contactId) {
        return repository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByDeliveredAtDesc(
                TenantContext.getCurrentOrgId(), contactId);
    }

    @Transactional(readOnly = true)
    public List<ProofOfDelivery> recent() {
        return repository.findTop50ByOrgIdAndIsDeletedFalseOrderByDeliveredAtDesc(
                TenantContext.getCurrentOrgId());
    }

    @Transactional
    public void delete(UUID id) {
        ProofOfDelivery pod = get(id);
        pod.setDeleted(true);
        repository.save(pod);
    }

    // ───────── Attachments (signature / photo) ─────────

    /** Upload a signature or photo against this POD, stored via AttachmentService. */
    @Transactional
    public EntityAttachment attachFile(UUID podId, MultipartFile file) {
        ProofOfDelivery pod = get(podId);   // ensures POD exists and is org-owned
        return attachmentService.upload(ATTACHMENT_ENTITY_TYPE, pod.getId(), file);
    }

    @Transactional(readOnly = true)
    public List<EntityAttachment> listAttachments(UUID podId) {
        ProofOfDelivery pod = get(podId);
        return attachmentService.list(ATTACHMENT_ENTITY_TYPE, pod.getId());
    }
}
