package com.katasticho.erp.common.policy;

import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PolicyResolverService {

    public static final String SALES_CREDIT_POLICY = "sales.credit_policy";
    public static final String SALES_OVERDUE_POLICY = "sales.overdue_policy";
    public static final String SALES_OVERDUE_GRACE_DAYS = "sales.overdue_grace_days";
    public static final String INVENTORY_BATCH_POLICY = "inventory.batch_policy";
    public static final String SALES_DISPATCH_MODE = "sales.dispatch_mode";

    private final OrgSettingsService orgSettingsService;

    public CreditPolicy creditPolicy(UUID orgId) {
        return resolveEnum(orgId, SALES_CREDIT_POLICY, CreditPolicy.WARN, CreditPolicy.class);
    }

    public OverduePolicy overduePolicy(UUID orgId) {
        return resolveEnum(orgId, SALES_OVERDUE_POLICY, OverduePolicy.WARN, OverduePolicy.class);
    }

    public int overdueGraceDays(UUID orgId) {
        String rawValue = orgSettingsService.get(orgId, SALES_OVERDUE_GRACE_DAYS, "0");
        try {
            return Math.max(0, Integer.parseInt(rawValue));
        } catch (Exception ex) {
            log.warn("Invalid org setting {}={} for org {}; using 0", SALES_OVERDUE_GRACE_DAYS, rawValue, orgId);
            return 0;
        }
    }

    public BatchPolicy batchPolicy(UUID orgId) {
        return resolveEnum(orgId, INVENTORY_BATCH_POLICY, BatchPolicy.FEFO, BatchPolicy.class);
    }

    public DispatchMode dispatchMode(UUID orgId) {
        return resolveEnum(orgId, SALES_DISPATCH_MODE, DispatchMode.CHALLAN_FIRST, DispatchMode.class);
    }

    private <E extends Enum<E>> E resolveEnum(UUID orgId, String key, E defaultValue, Class<E> enumType) {
        String rawValue = orgSettingsService.get(orgId, key, defaultValue.name());
        if (rawValue == null || rawValue.isBlank()) {
            return defaultValue;
        }

        try {
            return Enum.valueOf(enumType, rawValue.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException ex) {
            log.warn("Invalid org setting {}={} for org {}; using {}", key, rawValue, orgId, defaultValue.name());
            return defaultValue;
        }
    }
}
