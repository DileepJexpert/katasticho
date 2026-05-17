package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.entity.AiModelRun;
import com.katasticho.erp.ai.entity.AiUsageLog;
import com.katasticho.erp.ai.repository.AiModelRunRepository;
import com.katasticho.erp.ai.repository.AiUsageLogRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AiTelemetryServiceTest {

    private final AiModelRunRepository modelRunRepository = mock(AiModelRunRepository.class);
    private final AiUsageLogRepository usageLogRepository = mock(AiUsageLogRepository.class);
    private final AiTelemetryService service = new AiTelemetryService(modelRunRepository, usageLogRepository, new ObjectMapper());

    @Test
    void recordModelRunPersistsAuditMetadata() {
        UUID orgId = UUID.randomUUID();
        when(modelRunRepository.save(org.mockito.ArgumentMatchers.any(AiModelRun.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        AiModelRun run = service.recordModelRun(
                orgId,
                "INVOICE_REVIEW",
                "deterministic_rules",
                "1",
                "internal",
                Map.of("invoiceNumber", "INV-1"),
                Map.of("suggestionsCreated", 1),
                BigDecimal.ONE,
                12
        );

        assertThat(run.getOrgId()).isEqualTo(orgId);
        assertThat(run.getTaskType()).isEqualTo("INVOICE_REVIEW");
        assertThat(run.getInputHash()).hasSize(64);
        assertThat(run.getOutput()).containsEntry("suggestionsCreated", 1);
    }

    @Test
    void recordUsagePersistsCostAndEntityLink() {
        UUID orgId = UUID.randomUUID();
        UUID entityId = UUID.randomUUID();
        when(usageLogRepository.save(org.mockito.ArgumentMatchers.any(AiUsageLog.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        service.recordUsage(
                orgId,
                "BILL_SCAN",
                "anthropic",
                "claude-sonnet-4-20250514",
                100,
                50,
                new BigDecimal("0.001200"),
                "PURCHASE_BILL",
                entityId
        );

        ArgumentCaptor<AiUsageLog> captor = ArgumentCaptor.forClass(AiUsageLog.class);
        verify(usageLogRepository).save(captor.capture());
        assertThat(captor.getValue().getFeature()).isEqualTo("BILL_SCAN");
        assertThat(captor.getValue().getEntityId()).isEqualTo(entityId);
        assertThat(captor.getValue().getEstimatedCostUsd()).isEqualByComparingTo("0.001200");
    }

    @Test
    void recordModelRunUsesCanonicalInputHash() {
        when(modelRunRepository.save(org.mockito.ArgumentMatchers.any(AiModelRun.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        AiModelRun first = service.recordModelRun(
                UUID.randomUUID(), "TASK", "model", "1", "provider",
                Map.of("b", 2, "a", 1), Map.of(), BigDecimal.ONE, 1);
        AiModelRun second = service.recordModelRun(
                first.getOrgId(), "TASK", "model", "1", "provider",
                Map.of("a", 1, "b", 2), Map.of(), BigDecimal.ONE, 1);

        assertThat(first.getInputHash()).isEqualTo(second.getInputHash());
    }
}
