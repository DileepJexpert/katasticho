package com.katasticho.erp.common.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ModuleVisibilityServiceTest {

    @Mock private OrgSettingsService settingsService;
    private ModuleVisibilityService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ModuleVisibilityService(settingsService, new ObjectMapper());
    }

    @Test
    void getOverrides_unset_returnsEmpty() {
        when(settingsService.get(eq(orgId), eq("modules.visibility"), any())).thenReturn(null);
        assertTrue(service.getOverrides(orgId).isEmpty());
    }

    @Test
    void getOverrides_parsesAndDropsUnknownKeys_uppercases() {
        when(settingsService.get(eq(orgId), eq("modules.visibility"), any()))
                .thenReturn("{\"payroll\": false, \"MANUFACTURING\": true, \"BOGUS\": true}");
        Map<String, Boolean> ov = service.getOverrides(orgId);
        assertEquals(2, ov.size());
        assertEquals(Boolean.FALSE, ov.get("PAYROLL"));   // lowercased key uppercased
        assertEquals(Boolean.TRUE, ov.get("MANUFACTURING"));
        assertFalse(ov.containsKey("BOGUS"));             // unknown module dropped
    }

    @Test
    void getOverrides_malformedJson_returnsEmptyNotThrow() {
        when(settingsService.get(eq(orgId), eq("modules.visibility"), any()))
                .thenReturn("{not json");
        assertTrue(service.getOverrides(orgId).isEmpty());
    }

    @Test
    void setOverride_upsertsIntoExistingMapAndPersists() {
        when(settingsService.get(eq(orgId), eq("modules.visibility"), any()))
                .thenReturn("{\"PAYROLL\": false}");

        service.setOverride(orgId, "supply_chain", true);

        String saved = captureSaved();
        // Both the pre-existing override and the new one survive.
        assertTrue(saved.contains("\"PAYROLL\":false"));
        assertTrue(saved.contains("\"SUPPLY_CHAIN\":true"));
    }

    @Test
    void clearOverride_removesOneKey() {
        when(settingsService.get(eq(orgId), eq("modules.visibility"), any()))
                .thenReturn("{\"PAYROLL\": false, \"COURIER\": true}");

        service.clearOverride(orgId, "PAYROLL");

        String saved = captureSaved();
        assertFalse(saved.contains("PAYROLL"));
        assertTrue(saved.contains("\"COURIER\":true"));
    }

    @Test
    void reset_persistsEmptyMap() {
        service.reset(orgId);
        assertEquals("{}", captureSaved());
    }

    @Test
    void setOverride_unknownModule_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.setOverride(orgId, "NONSENSE", true));
        assertEquals("MODULE_VISIBILITY_UNKNOWN_MODULE", ex.getErrorCode());
        verify(settingsService, never()).set(any(), any(), any());
    }

    @Test
    void isolation_readsAndWritesOnlyTheCallersOrgKey() {
        when(settingsService.get(eq(orgId), eq("modules.visibility"), any())).thenReturn(null);
        service.setOverride(orgId, "PAYROLL", true);
        // Never touches any other org — only (orgId, "modules.visibility").
        verify(settingsService).set(eq(orgId), eq("modules.visibility"), any());
        verify(settingsService, never()).set(argThat(id -> !orgId.equals(id)), any(), any());
    }

    private String captureSaved() {
        ArgumentCaptor<String> cap = ArgumentCaptor.forClass(String.class);
        verify(settingsService).set(eq(orgId), eq("modules.visibility"), cap.capture());
        return cap.getValue();
    }
}
