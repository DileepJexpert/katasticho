package com.katasticho.erp.common.module;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.billing.SubscriptionEntitlementService;
import com.katasticho.erp.common.service.FeatureFlagService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ModuleAccessServiceTest {

    @Mock
    private FeatureFlagService featureFlagService;

    @Mock
    private SubscriptionEntitlementService subscriptionEntitlementService;

    @InjectMocks
    private ModuleAccessService moduleAccessService;

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void requireEnabledPassesWhenFeatureFlagIsEnabled() {
        UUID orgId = UUID.randomUUID();
        when(subscriptionEntitlementService.isEntitled(orgId, ModuleCode.POS)).thenReturn(true);
        when(featureFlagService.isEnabled(orgId, ModuleCode.POS)).thenReturn(true);

        assertThatCode(() -> moduleAccessService.requireEnabled(orgId, ModuleCode.POS))
                .doesNotThrowAnyException();
    }

    @Test
    void requireEnabledRejectsDisabledModule() {
        UUID orgId = UUID.randomUUID();
        when(subscriptionEntitlementService.isEntitled(orgId, ModuleCode.POS)).thenReturn(true);
        when(featureFlagService.isEnabled(orgId, ModuleCode.POS)).thenReturn(false);

        assertThatThrownBy(() -> moduleAccessService.requireEnabled(orgId, ModuleCode.POS))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("MODULE_NOT_ENABLED");
                    assertThat(ex.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
                });
    }

    @Test
    void requireEnabledUsesTenantContext() {
        UUID orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        when(subscriptionEntitlementService.isEntitled(orgId, ModuleCode.AI_INBOX)).thenReturn(true);
        when(featureFlagService.isEnabled(orgId, ModuleCode.AI_INBOX)).thenReturn(true);

        assertThatCode(() -> moduleAccessService.requireEnabled(ModuleCode.AI_INBOX))
                .doesNotThrowAnyException();
    }

    @Test
    void requireEnabledRejectsMissingTenantContext() {
        assertThatThrownBy(() -> moduleAccessService.requireEnabled(ModuleCode.ACCOUNTING))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("ORG_CONTEXT_REQUIRED");
                    assertThat(ex.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
                });
    }

    @Test
    void isEnabledReturnsFalseWhenOrgIsMissing() {
        assertThat(moduleAccessService.isEnabled(null, ModuleCode.REPORTS)).isFalse();
    }

    @Test
    void ownerStillCannotBypassSubscriptionEntitlementWhenBillingIsEnforced() {
        UUID orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentRole("OWNER");

        org.mockito.Mockito.doThrow(new BusinessException(
                        "Module is not included in this organisation's subscription plan: POS",
                        "MODULE_NOT_INCLUDED_IN_PLAN",
                        HttpStatus.FORBIDDEN
                ))
                .when(subscriptionEntitlementService).requireEntitled(orgId, ModuleCode.POS);

        assertThatThrownBy(() -> moduleAccessService.requireEnabled(ModuleCode.POS))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("MODULE_NOT_INCLUDED_IN_PLAN"));
    }
}
