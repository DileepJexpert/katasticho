package com.katasticho.erp.workflow.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.workflow.entity.WorkflowRuleExecution;
import com.katasticho.erp.workflow.repository.WorkflowRuleExecutionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.UUID;

/**
 * Writes the workflow execution log in its OWN transaction (REQUIRES_NEW) so
 * the dedupe row commits independently of the domain-event processing
 * transaction. If another handler on the same event later fails and the event
 * is retried (the bus is at-least-once), the committed execution row makes the
 * retry skip this already-run rule — preventing a duplicate email/webhook.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class WorkflowExecutionRecorder {

    private final WorkflowRuleExecutionRepository executionRepository;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(UUID ruleId, UUID eventId, String entityType, UUID entityId,
                       boolean matched, String status, int actionsRun, Map<String, Object> detail) {
        try {
            WorkflowRuleExecution row = WorkflowRuleExecution.builder()
                    .ruleId(ruleId).eventId(eventId)
                    .entityType(entityType).entityId(entityId)
                    .matched(matched).status(status).actionsRun(actionsRun)
                    .detail(detail)
                    .build();
            row.setOrgId(TenantContext.getCurrentOrgId());
            row.setCreatedBy(TenantContext.getCurrentUserId());
            executionRepository.save(row);
        } catch (Exception e) {
            // Never let logging failure break the event flow.
            log.warn("Failed to record workflow execution for rule {}: {}", ruleId, e.getMessage());
        }
    }
}
