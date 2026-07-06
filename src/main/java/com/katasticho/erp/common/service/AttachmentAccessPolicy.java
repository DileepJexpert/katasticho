package com.katasticho.erp.common.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Function-level + per-entityType authorization for the GENERIC attachment API.
 * The generic list/download/delete endpoints are org-scoped only, so without this
 * any authenticated role could read HR-document PII or delete POD evidence,
 * bypassing the per-domain controllers' role gates. Enforced in the SERVICE so it
 * applies to JWT and API-key callers alike. Fail-closed: an unknown entityType is
 * OWNER/ADMIN-only.
 */
@Component
public class AttachmentAccessPolicy {

    public void assertCanRead(String entityType, UUID entityId) {
        switch (norm(entityType)) {
            case "EMPLOYEE" -> requireOwnerAdminOrSelf(entityId);
            case "POD" -> requireAnyRole("OWNER", "ADMIN", "ACCOUNTANT", "OPERATOR");
            case "OPERATION" -> requireAnyRole("OWNER", "ADMIN", "OPERATOR");
            // BILL attachments mirror PurchaseBillController's read gate.
            case "BILL" -> requireAnyRole("OWNER", "ADMIN", "ACCOUNTANT", "VIEWER");
            default -> requireAnyRole("OWNER", "ADMIN");
        }
    }

    public void assertCanDelete(String entityType, UUID entityId) {
        switch (norm(entityType)) {
            case "EMPLOYEE" -> requireOwnerAdminOrSelf(entityId);
            case "POD" -> requireAnyRole("OWNER", "ADMIN", "ACCOUNTANT");
            case "OPERATION" -> requireAnyRole("OWNER", "ADMIN", "OPERATOR");
            // BILL attachments are uploaded by OWNER/ADMIN/ACCOUNTANT — same gate to delete.
            case "BILL" -> requireAnyRole("OWNER", "ADMIN", "ACCOUNTANT");
            default -> requireAnyRole("OWNER", "ADMIN");
        }
    }

    private void requireOwnerAdminOrSelf(UUID entityId) {
        if (hasAnyRole("OWNER", "ADMIN")) return;
        if (entityId != null && entityId.equals(TenantContext.getCurrentUserId())) return;
        throw forbidden();
    }

    private void requireAnyRole(String... roles) {
        if (!hasAnyRole(roles)) throw forbidden();
    }

    private boolean hasAnyRole(String... roles) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        Set<String> held = auth == null ? Set.of()
                : auth.getAuthorities().stream()
                        .map(GrantedAuthority::getAuthority)
                        .collect(Collectors.toSet());
        for (String r : roles) {
            if (held.contains("ROLE_" + r) || held.contains(r)) return true;
        }
        // Fall back to TenantContext role (API-key filter sets it there too).
        String ctxRole = TenantContext.getCurrentRole();
        if (ctxRole != null) {
            for (String r : roles) {
                if (ctxRole.contains(r)) return true;
            }
        }
        return false;
    }

    private static String norm(String entityType) {
        return entityType == null ? "" : entityType.trim().toUpperCase();
    }

    private static BusinessException forbidden() {
        return new BusinessException("Not permitted to access this attachment",
                "ATTACHMENT_FORBIDDEN", HttpStatus.FORBIDDEN);
    }
}
