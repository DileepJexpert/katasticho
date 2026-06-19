package com.katasticho.erp.fieldforce.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.fieldforce.entity.FieldSyncEntry;
import com.katasticho.erp.fieldforce.repository.FieldSyncEntryRepository;
import com.katasticho.erp.fieldsales.service.FieldTrackingService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class FieldSyncActionProcessorTest {

    @Mock private FieldFacadeService facade;
    @Mock private FieldSyncEntryRepository syncRepository;
    private FieldSyncActionProcessor processor;

    private final UUID orgId = UUID.randomUUID();
    private final UUID me = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        processor = new FieldSyncActionProcessor(facade, syncRepository);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(me);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void process_newPingAction_appliesAndWritesLedger() {
        when(syncRepository.findByOrgIdAndSalespersonIdAndClientId(orgId, me, "c1"))
                .thenReturn(Optional.empty());
        when(facade.recordPings(any())).thenReturn(2);

        Map<String, Object> r = processor.process("c1", "LOCATION_PINGS",
                Map.of("pings", List.of(Map.of("latitude", 1, "longitude", 2))));

        assertEquals("APPLIED", r.get("status"));
        verify(facade).recordPings(any());
        verify(syncRepository).save(any(FieldSyncEntry.class));
    }

    @Test
    void process_replayedClientId_returnsDuplicateWithoutReapplying() {
        when(syncRepository.findByOrgIdAndSalespersonIdAndClientId(orgId, me, "c1"))
                .thenReturn(Optional.of(FieldSyncEntry.builder().status("APPLIED").build()));

        Map<String, Object> r = processor.process("c1", "LOCATION_PINGS", Map.of());

        assertEquals("DUPLICATE", r.get("status"));
        verifyNoInteractions(facade);
        verify(syncRepository, never()).save(any());
    }

    @Test
    void process_unknownType_throws() {
        when(syncRepository.findByOrgIdAndSalespersonIdAndClientId(orgId, me, "c1"))
                .thenReturn(Optional.empty());
        assertThrows(RuntimeException.class, () -> processor.process("c1", "NONSENSE", Map.of()));
        verify(syncRepository, never()).save(any());
    }
}
