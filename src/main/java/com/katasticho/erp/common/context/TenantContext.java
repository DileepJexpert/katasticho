package com.katasticho.erp.common.context;

import java.util.UUID;

/**
 * Thread-local holder for the current tenant (org) and user context.
 * Populated from JWT claims on every authenticated request by the security filter.
 */
public final class TenantContext {

    private TenantContext() {}

    private static final ThreadLocal<UUID> CURRENT_ORG_ID = new ThreadLocal<>();
    private static final ThreadLocal<UUID> CURRENT_USER_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> CURRENT_ROLE = new ThreadLocal<>();

    public static UUID getCurrentOrgId() {
        return CURRENT_ORG_ID.get();
    }

    public static void setCurrentOrgId(UUID orgId) {
        CURRENT_ORG_ID.set(orgId);
    }

    public static UUID getCurrentUserId() {
        return CURRENT_USER_ID.get();
    }

    public static void setCurrentUserId(UUID userId) {
        CURRENT_USER_ID.set(userId);
    }

    public static String getCurrentRole() {
        return CURRENT_ROLE.get();
    }

    public static void setCurrentRole(String role) {
        CURRENT_ROLE.set(role);
    }

    public static void clear() {
        CURRENT_ORG_ID.remove();
        CURRENT_USER_ID.remove();
        CURRENT_ROLE.remove();
    }
}
