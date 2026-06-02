package com.katasticho.erp.common.policy;

import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class PolicyResolverServiceTest {

    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);
    private final PolicyResolverService service = new PolicyResolverService(orgSettingsService);
    private final UUID orgId = UUID.randomUUID();

    @Test
    void creditPolicy_missingSettingDefaultsToWarn() {
        when(orgSettingsService.get(orgId, PolicyResolverService.SALES_CREDIT_POLICY, CreditPolicy.WARN.name()))
                .thenReturn(CreditPolicy.WARN.name());

        assertEquals(CreditPolicy.WARN, service.creditPolicy(orgId));
    }

    @Test
    void creditPolicy_invalidSettingDefaultsToWarn() {
        when(orgSettingsService.get(orgId, PolicyResolverService.SALES_CREDIT_POLICY, CreditPolicy.WARN.name()))
                .thenReturn("HOLD_FOR_MANAGER");

        assertEquals(CreditPolicy.WARN, service.creditPolicy(orgId));
    }

    @Test
    void batchPolicy_lowercaseValueIsAccepted() {
        when(orgSettingsService.get(orgId, PolicyResolverService.INVENTORY_BATCH_POLICY, BatchPolicy.FEFO.name()))
                .thenReturn("fifo");

        assertEquals(BatchPolicy.FIFO, service.batchPolicy(orgId));
    }

    @Test
    void dispatchMode_missingSettingDefaultsToChallanFirst() {
        when(orgSettingsService.get(orgId, PolicyResolverService.SALES_DISPATCH_MODE, DispatchMode.CHALLAN_FIRST.name()))
                .thenReturn(DispatchMode.CHALLAN_FIRST.name());

        assertEquals(DispatchMode.CHALLAN_FIRST, service.dispatchMode(orgId));
    }

    @Test
    void schemeApplyMode_missingSettingDefaultsToManual() {
        when(orgSettingsService.get(orgId, PolicyResolverService.SALES_SCHEME_APPLY_MODE, SchemeApplyMode.MANUAL.name()))
                .thenReturn(SchemeApplyMode.MANUAL.name());

        assertEquals(SchemeApplyMode.MANUAL, service.schemeApplyMode(orgId));
    }

    @Test
    void schemeApplyMode_invalidSettingDefaultsToManual() {
        when(orgSettingsService.get(orgId, PolicyResolverService.SALES_SCHEME_APPLY_MODE, SchemeApplyMode.MANUAL.name()))
                .thenReturn("SMART");

        assertEquals(SchemeApplyMode.MANUAL, service.schemeApplyMode(orgId));
    }

    @Test
    void overduePolicy_missingSettingDefaultsToWarn() {
        when(orgSettingsService.get(orgId, PolicyResolverService.SALES_OVERDUE_POLICY, OverduePolicy.WARN.name()))
                .thenReturn(OverduePolicy.WARN.name());

        assertEquals(OverduePolicy.WARN, service.overduePolicy(orgId));
    }

    @Test
    void overdueGraceDays_invalidSettingDefaultsToZero() {
        when(orgSettingsService.get(orgId, PolicyResolverService.SALES_OVERDUE_GRACE_DAYS, "0"))
                .thenReturn("many");

        assertEquals(0, service.overdueGraceDays(orgId));
    }
}
