package com.katasticho.erp.workflow.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.Set;
import java.util.UUID;

/**
 * FIELD_UPDATE mutator for invoices. Allows ONLY the two soft text fields
 * (notes, termsAndConditions) — never status, amounts, journalEntryId or any
 * posting-driving column — and writes through the plain repository, so a rule
 * can annotate a posted invoice but can never alter its ledger position.
 */
@Component
@RequiredArgsConstructor
public class InvoiceFieldMutator implements WorkflowFieldMutator {

    private static final Set<String> ALLOWED = Set.of("notes", "termsAndConditions");

    private final InvoiceRepository invoiceRepository;

    @Override
    public boolean supports(String entityType) {
        return "INVOICE".equals(entityType);
    }

    @Override
    public Set<String> allowedFields() {
        return ALLOWED;
    }

    @Override
    public void apply(UUID entityId, String field, Object value) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Invoice inv = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(entityId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", entityId));
        String text = value == null ? null : value.toString();
        switch (field) {
            case "notes" -> inv.setNotes(text);
            case "termsAndConditions" -> inv.setTermsAndConditions(text);
            default -> throw new BusinessException("Field not writable: " + field,
                    "WORKFLOW_FIELD_NOT_WRITABLE", HttpStatus.BAD_REQUEST);
        }
        invoiceRepository.save(inv);
    }
}
