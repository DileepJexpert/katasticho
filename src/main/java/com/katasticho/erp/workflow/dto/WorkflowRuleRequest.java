package com.katasticho.erp.workflow.dto;

import com.katasticho.erp.workflow.entity.WorkflowAction;
import com.katasticho.erp.workflow.entity.WorkflowCriterion;
import com.katasticho.erp.workflow.entity.WorkflowRule;

import java.util.ArrayList;
import java.util.List;

/** Create/update payload for a workflow rule. */
public record WorkflowRuleRequest(
        String name,
        String description,
        String entityType,
        String triggerEvent,
        String matchType,
        List<WorkflowCriterion> criteria,
        List<WorkflowAction> actions,
        Integer runOrder,
        Boolean active) {

    public WorkflowRule toEntity() {
        return WorkflowRule.builder()
                .name(name)
                .description(description)
                .entityType(entityType)
                .triggerEvent(triggerEvent)
                .matchType(matchType == null || matchType.isBlank() ? "ALL" : matchType.toUpperCase())
                .criteria(criteria == null ? new ArrayList<>() : criteria)
                .actions(actions == null ? new ArrayList<>() : actions)
                .runOrder(runOrder == null ? 0 : runOrder)
                .active(Boolean.TRUE.equals(active))
                .build();
    }
}
