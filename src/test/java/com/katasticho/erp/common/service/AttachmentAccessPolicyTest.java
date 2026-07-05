package com.katasticho.erp.common.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Verifies the per-entityType authorization on the generic attachment API.
 * Without it, any authenticated role could read HR-document PII or delete POD
 * evidence via the generic list/download/delete endpoints.
 */
class AttachmentAccessPolicyTest {

    private final AttachmentAccessPolicy policy = new AttachmentAccessPolicy();

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
        TenantContext.clear();
    }

    private void authAs(String... roles) {
        List<SimpleGrantedAuthority> auths = java.util.Arrays.stream(roles)
                .map(r -> new SimpleGrantedAuthority("ROLE_" + r))
                .toList();
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("u", "p", auths));
    }

    private static void assertForbidden(Runnable r) {
        assertThatThrownBy(r::run)
                .isInstanceOf(BusinessException.class)
                .satisfies(t -> assertThat(((BusinessException) t).getErrorCode())
                        .isEqualTo("ATTACHMENT_FORBIDDEN"));
    }

    // ── EMPLOYEE: OWNER/ADMIN or the employee themself ──────────────

    @Test
    void employee_read_allowed_for_admin() {
        authAs("ADMIN");
        policy.assertCanRead("EMPLOYEE", UUID.randomUUID()); // no throw
    }

    @Test
    void employee_read_allowed_for_self() {
        UUID me = UUID.randomUUID();
        authAs("OPERATOR");
        TenantContext.setCurrentUserId(me);
        policy.assertCanRead("EMPLOYEE", me); // self
    }

    @Test
    void employee_read_denied_for_other_operator() {
        authAs("OPERATOR");
        TenantContext.setCurrentUserId(UUID.randomUUID());
        assertForbidden(() -> policy.assertCanRead("EMPLOYEE", UUID.randomUUID()));
    }

    // ── POD: read incl. OPERATOR; delete excludes OPERATOR ──────────

    @Test
    void pod_read_allowed_for_operator_but_delete_denied() {
        authAs("OPERATOR");
        policy.assertCanRead("POD", UUID.randomUUID()); // delivery boy can view
        assertForbidden(() -> policy.assertCanDelete("POD", UUID.randomUUID()));
    }

    @Test
    void pod_delete_allowed_for_accountant() {
        authAs("ACCOUNTANT");
        policy.assertCanDelete("POD", UUID.randomUUID());
    }

    // ── BILL: mirrors PurchaseBillController's gate ─────────────────

    @Test
    void bill_read_allowed_for_accountant_and_viewer() {
        authAs("ACCOUNTANT");
        policy.assertCanRead("BILL", UUID.randomUUID());
        SecurityContextHolder.clearContext();
        authAs("VIEWER");
        policy.assertCanRead("BILL", UUID.randomUUID());
    }

    @Test
    void bill_delete_denied_for_viewer_allowed_for_accountant() {
        authAs("VIEWER");
        assertForbidden(() -> policy.assertCanDelete("BILL", UUID.randomUUID()));
        SecurityContextHolder.clearContext();
        authAs("ACCOUNTANT");
        policy.assertCanDelete("BILL", UUID.randomUUID());
    }

    // ── OPERATION: OWNER/ADMIN/OPERATOR ─────────────────────────────

    @Test
    void operation_read_allowed_for_operator_denied_for_accountant() {
        authAs("OPERATOR");
        policy.assertCanRead("OPERATION", UUID.randomUUID());
        SecurityContextHolder.clearContext();
        authAs("ACCOUNTANT");
        assertForbidden(() -> policy.assertCanRead("OPERATION", UUID.randomUUID()));
    }

    // ── Unknown entityType: fail-closed to OWNER/ADMIN ──────────────

    @Test
    void unknown_type_is_owner_admin_only() {
        authAs("ACCOUNTANT");
        assertForbidden(() -> policy.assertCanRead("MYSTERY", UUID.randomUUID()));
        SecurityContextHolder.clearContext();
        authAs("OWNER");
        policy.assertCanRead("MYSTERY", UUID.randomUUID());
    }

    // ── API-key fallback: role only in TenantContext ────────────────

    @Test
    void tenant_context_role_is_honored_when_no_security_context() {
        // API-key filter sets the role in TenantContext, not SecurityContext.
        TenantContext.setCurrentRole("ROLE_ADMIN");
        policy.assertCanRead("BILL", UUID.randomUUID());
    }

    @Test
    void no_auth_at_all_is_denied() {
        assertThatThrownBy(() -> policy.assertCanRead("BILL", UUID.randomUUID()))
                .isInstanceOf(BusinessException.class);
    }
}
