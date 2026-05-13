package com.katasticho.erp.common.billing;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class SubscriptionEntitlementServiceTest {

    private final OrganisationRepository organisationRepository = mock(OrganisationRepository.class);
    private final SubscriptionEntitlementService service = new SubscriptionEntitlementService(organisationRepository);

    @Test
    void disabledBillingEnforcementAllowsEveryModule() {
        ReflectionTestUtils.setField(service, "enforcementEnabled", false);

        assertThat(service.isEntitled(UUID.randomUUID(), ModuleCode.MANUFACTURING)).isTrue();
    }

    @Test
    void enabledBillingEnforcementUsesPlanEntitlements() {
        UUID orgId = UUID.randomUUID();
        ReflectionTestUtils.setField(service, "enforcementEnabled", true);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(Organisation.builder()
                .id(orgId)
                .name("Test Org")
                .planTier("STARTER_FINANCE")
                .build()));

        assertThat(service.isEntitled(orgId, ModuleCode.ACCOUNTING)).isTrue();
        assertThat(service.isEntitled(orgId, ModuleCode.POS)).isFalse();
    }

    @Test
    void requireEntitledRejectsModuleOutsidePlan() {
        UUID orgId = UUID.randomUUID();
        ReflectionTestUtils.setField(service, "enforcementEnabled", true);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(Organisation.builder()
                .id(orgId)
                .name("Test Org")
                .planTier("STARTER_FINANCE")
                .build()));

        assertThatThrownBy(() -> service.requireEntitled(orgId, ModuleCode.POS))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("MODULE_NOT_INCLUDED_IN_PLAN"));
    }
}
