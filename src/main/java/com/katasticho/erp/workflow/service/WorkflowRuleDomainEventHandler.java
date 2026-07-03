package com.katasticho.erp.workflow.service;

import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.event.DomainEventHandler;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Rides the existing domain-event bus for EVERY event type ({@code supports}
 * returns true) so the workflow engine needs no new publish call-sites. Failures
 * are swallowed here: workflow automation is non-critical, and letting it throw
 * would retry the whole event and starve the AI / e-invoice / e-way handlers
 * that share the same event (the bus is at-least-once). Per-rule isolation lives
 * inside {@link WorkflowRuleService#evaluate}.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class WorkflowRuleDomainEventHandler implements DomainEventHandler {

    private final WorkflowRuleService workflowRuleService;

    @Override
    public boolean supports(String eventType) {
        return true;
    }

    @Override
    public void handle(DomainEvent event) {
        try {
            workflowRuleService.evaluate(event);
        } catch (Exception e) {
            log.warn("Workflow evaluation failed for event {} ({}): {}",
                    event.getId(), event.getEventType(), e.getMessage());
        }
    }
}
