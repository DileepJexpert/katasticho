package com.katasticho.erp.platform.context;

import java.util.UUID;

public class PlatformAdminContext {
    private static final ThreadLocal<UUID> ADMIN_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> ADMIN_ROLE = new ThreadLocal<>();

    public static void set(UUID adminId, String role) {
        ADMIN_ID.set(adminId);
        ADMIN_ROLE.set(role);
    }
    public static UUID getAdminId() { return ADMIN_ID.get(); }
    public static String getAdminRole() { return ADMIN_ROLE.get(); }
    public static void clear() { ADMIN_ID.remove(); ADMIN_ROLE.remove(); }
}
