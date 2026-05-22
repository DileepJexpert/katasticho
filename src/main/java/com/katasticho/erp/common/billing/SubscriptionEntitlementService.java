package com.katasticho.erp.common.billing;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SubscriptionEntitlementService {

    private static final Set<String> ALL_MODULES = Set.of(
            ModuleCode.ACCOUNTING,
            ModuleCode.AR,
            ModuleCode.AP,
            ModuleCode.GST,
            ModuleCode.BANK_RECON,
            ModuleCode.AI_INBOX,
            ModuleCode.REPORTS,
            ModuleCode.COLLECTIONS,
            ModuleCode.POS,
            ModuleCode.INVENTORY,
            ModuleCode.PHARMA,
            ModuleCode.MANUFACTURING,
            ModuleCode.RECURRING_BILLING,
            ModuleCode.MULTI_ENTITY,
            ModuleCode.PAYMENTS,
            ModuleCode.BATCH_EXPIRY,
            ModuleCode.CA_CONSOLE
    );

    private static final Map<String, Set<String>> PLAN_ENTITLEMENTS = Map.of(
            "FREE_BETA", ALL_MODULES,
            "STARTER_FINANCE", Set.of(
                    ModuleCode.ACCOUNTING,
                    ModuleCode.AR,
                    ModuleCode.AP,
                    ModuleCode.GST,
                    ModuleCode.REPORTS,
                    ModuleCode.PAYMENTS
            ),
            "AI_FINANCE", Set.of(
                    ModuleCode.ACCOUNTING,
                    ModuleCode.AR,
                    ModuleCode.AP,
                    ModuleCode.GST,
                    ModuleCode.BANK_RECON,
                    ModuleCode.AI_INBOX,
                    ModuleCode.REPORTS,
                    ModuleCode.COLLECTIONS,
                    ModuleCode.PAYMENTS
            ),
            "RETAIL", Set.of(
                    ModuleCode.ACCOUNTING,
                    ModuleCode.AR,
                    ModuleCode.AP,
                    ModuleCode.GST,
                    ModuleCode.REPORTS,
                    ModuleCode.PAYMENTS,
                    ModuleCode.POS,
                    ModuleCode.INVENTORY
            ),
            "PHARMA", Set.of(
                    ModuleCode.ACCOUNTING,
                    ModuleCode.AR,
                    ModuleCode.AP,
                    ModuleCode.GST,
                    ModuleCode.BANK_RECON,
                    ModuleCode.AI_INBOX,
                    ModuleCode.REPORTS,
                    ModuleCode.PAYMENTS,
                    ModuleCode.INVENTORY,
                    ModuleCode.PHARMA,
                    ModuleCode.BATCH_EXPIRY
            ),
            "ENTERPRISE", ALL_MODULES
    );

    private final OrganisationRepository organisationRepository;

    @Value("${app.billing.enforcement-enabled:false}")
    private boolean enforcementEnabled;

    public boolean isEntitled(UUID orgId, String moduleCode) {
        if (!enforcementEnabled) {
            return true;
        }
        String planTier = organisationRepository.findById(orgId)
                .map(org -> org.getPlanTier() == null ? "FREE_BETA" : org.getPlanTier())
                .orElse("FREE_BETA");
        return PLAN_ENTITLEMENTS.getOrDefault(planTier, Set.of()).contains(moduleCode);
    }

    public void requireEntitled(UUID orgId, String moduleCode) {
        if (!isEntitled(orgId, moduleCode)) {
            throw new BusinessException(
                    "Module is not included in this organisation's subscription plan: " + moduleCode,
                    "MODULE_NOT_INCLUDED_IN_PLAN",
                    HttpStatus.FORBIDDEN
            );
        }
    }
}
