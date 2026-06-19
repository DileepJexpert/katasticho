package com.katasticho.erp.fieldforce.service;

import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FieldSyncServiceTest {

    @Mock private FieldSyncActionProcessor processor;
    private FieldSyncService service;

    @BeforeEach
    void setUp() {
        service = new FieldSyncService(processor);
    }

    private Map<String, Object> action(String clientId, String type) {
        return Map.of("clientId", clientId, "type", type, "payload", Map.of());
    }

    @Test
    void push_isolatesFailuresAndCountsOutcomes() {
        when(processor.process(eq("c1"), any(), any()))
                .thenReturn(Map.of("clientId", "c1", "type", "CHECK_IN", "status", "APPLIED"));
        when(processor.process(eq("c2"), any(), any()))
                .thenReturn(Map.of("clientId", "c2", "type", "ORDER", "status", "DUPLICATE"));
        when(processor.process(eq("c3"), any(), any()))
                .thenThrow(new BusinessException("boom", "FIELD_SYNC_UNKNOWN_TYPE"));

        Map<String, Object> r = service.push(List.of(
                action("c1", "CHECK_IN"), action("c2", "ORDER"), action("c3", "WAT")));

        assertEquals(3, r.get("total"));
        assertEquals(1, r.get("applied"));
        assertEquals(1, r.get("duplicate"));
        assertEquals(1, r.get("failed"));
        // a failing action does not stop the others — all three were attempted
        verify(processor, times(3)).process(any(), any(), any());
    }

    @Test
    void push_missingClientId_failsWithoutCallingProcessor() {
        Map<String, Object> r = service.push(List.of(Map.of("type", "CHECK_IN", "payload", Map.of())));

        assertEquals(1, r.get("failed"));
        verify(processor, never()).process(any(), any(), any());
    }

    @Test
    void push_nullActions_throws() {
        assertThrows(BusinessException.class, () -> service.push(null));
    }
}
