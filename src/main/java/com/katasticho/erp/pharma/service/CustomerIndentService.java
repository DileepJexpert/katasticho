package com.katasticho.erp.pharma.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.pharma.dto.CustomerIndentRequest;
import com.katasticho.erp.pharma.dto.CustomerIndentResponse;
import com.katasticho.erp.pharma.entity.CustomerIndent;
import com.katasticho.erp.pharma.repository.CustomerIndentRepository;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class CustomerIndentService {

    private static final List<String> STOCK_WAITING_STATUSES = List.of("REQUESTED", "ORDERED");

    private final CustomerIndentRepository indentRepository;
    private final ItemRepository itemRepository;
    private final ContactRepository contactRepository;
    private final EntityManager entityManager;
    private final AuditService auditService;

    @Transactional
    public CustomerIndentResponse create(CustomerIndentRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(request.itemId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", request.itemId()));

        String customerName = request.customerName().trim();
        String customerPhone = blankToNull(request.customerPhone());
        UUID contactId = request.contactId();
        if (contactId != null) {
            Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Contact", contactId));
            if (customerName.isBlank()) {
                customerName = contact.getDisplayName();
            }
            if (customerPhone == null) {
                customerPhone = contact.getPhone() != null ? contact.getPhone() : contact.getMobile();
            }
        }
        if (customerName.isBlank()) {
            throw new BusinessException("Customer name is required",
                    "INDENT_CUSTOMER_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        CustomerIndent indent = CustomerIndent.builder()
                .indentNumber(nextIndentNumber())
                .contactId(contactId)
                .customerName(customerName)
                .customerPhone(customerPhone)
                .itemId(item.getId())
                .itemName(item.getName())
                .itemSku(item.getSku())
                .quantity(request.quantity().setScale(4, RoundingMode.HALF_UP))
                .status("REQUESTED")
                .source(normalizeSource(request.source()))
                .neededBy(request.neededBy())
                .notes(blankToNull(request.notes()))
                .build();
        indent.setOrgId(orgId);
        indent = indentRepository.save(indent);

        auditService.log("CUSTOMER_INDENT", indent.getId(), "CREATE", null,
                "{\"indentNumber\":\"" + indent.getIndentNumber() + "\",\"itemSku\":\""
                        + safe(indent.getItemSku()) + "\"}");
        return toResponse(indent);
    }

    @Transactional(readOnly = true)
    public Page<CustomerIndentResponse> list(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<CustomerIndent> page = status == null || status.isBlank()
                ? indentRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                : indentRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, status.toUpperCase(), pageable);
        return page.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public CustomerIndentResponse getById(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return indentRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .map(this::toResponse)
                .orElseThrow(() -> BusinessException.notFound("CustomerIndent", id));
    }

    @Transactional
    public CustomerIndentResponse updateStatus(UUID id, String status) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomerIndent indent = indentRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("CustomerIndent", id));
        String next = normalizeStatus(status);
        String previous = indent.getStatus();
        indent.setStatus(next);
        if ("NOTIFIED".equals(next)) {
            indent.setNotifiedAt(Instant.now());
        }
        if ("FULFILLED".equals(next)) {
            indent.setFulfilledAt(Instant.now());
        }
        indent = indentRepository.save(indent);
        auditService.log("CUSTOMER_INDENT", indent.getId(), "STATUS",
                "{\"status\":\"" + previous + "\"}", "{\"status\":\"" + next + "\"}");
        return toResponse(indent);
    }

    @Transactional
    public void cancel(UUID id) {
        updateStatus(id, "CANCELLED");
    }

    @Transactional
    public int onStockReceived(UUID orgId, UUID itemId) {
        List<CustomerIndent> indents = indentRepository.findOpenForItem(orgId, itemId, STOCK_WAITING_STATUSES);
        int updated = 0;
        for (CustomerIndent indent : indents) {
            indent.setStatus("RECEIVED");
            updated++;
        }
        if (updated > 0) {
            log.info("Customer indents marked RECEIVED for item {}: {}", itemId, updated);
        }
        return updated;
    }

    private CustomerIndentResponse toResponse(CustomerIndent i) {
        return new CustomerIndentResponse(
                i.getId(),
                i.getIndentNumber(),
                i.getContactId(),
                i.getCustomerName(),
                i.getCustomerPhone(),
                i.getItemId(),
                i.getItemName(),
                i.getItemSku(),
                i.getQuantity(),
                i.getStatus(),
                i.getSource(),
                i.getNeededBy(),
                i.getNotes(),
                i.getNotifiedAt(),
                i.getFulfilledAt(),
                i.getCreatedAt());
    }

    private String nextIndentNumber() {
        Number next = (Number) entityManager
                .createNativeQuery("SELECT nextval('customer_indent_seq')")
                .getSingleResult();
        return "IND-" + String.format("%06d", next.longValue());
    }

    private String normalizeSource(String source) {
        String value = source == null || source.isBlank() ? "MANUAL" : source.trim().toUpperCase();
        return switch (value) {
            case "POS", "PHONE", "WHATSAPP", "MANUAL" -> value;
            default -> "MANUAL";
        };
    }

    private String normalizeStatus(String status) {
        String value = status == null ? "" : status.trim().toUpperCase();
        return switch (value) {
            case "REQUESTED", "ORDERED", "RECEIVED", "NOTIFIED", "FULFILLED", "CANCELLED" -> value;
            default -> throw new BusinessException("Invalid indent status: " + status,
                    "INDENT_INVALID_STATUS", HttpStatus.BAD_REQUEST);
        };
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }
}
