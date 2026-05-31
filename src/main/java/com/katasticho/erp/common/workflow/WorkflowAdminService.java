package com.katasticho.erp.common.workflow;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class WorkflowAdminService {

    private final WorkflowDefinitionRepository workflowDefinitionRepository;
    private final DocumentStateConfigRepository documentStateConfigRepository;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public List<WorkflowDefinitionResponse> listWorkflows() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return workflowDefinitionRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId)
                .stream()
                .map(WorkflowDefinitionResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public WorkflowDefinitionResponse getWorkflow(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return WorkflowDefinitionResponse.from(findWorkflow(orgId, id));
    }

    @Transactional
    public WorkflowDefinitionResponse updateWorkflow(UUID id, WorkflowUpdateRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WorkflowDefinition workflow = findWorkflow(orgId, id);

        if (request.active() != null) {
            workflow.setActive(request.active());
        }
        if (request.triggerCondition() != null) {
            validateJson(request.triggerCondition());
            workflow.setTriggerCondition(request.triggerCondition());
        }

        return WorkflowDefinitionResponse.from(workflowDefinitionRepository.save(workflow));
    }

    @Transactional
    public WorkflowDefinitionResponse replaceSteps(UUID id, List<WorkflowStepRequest> requests) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WorkflowDefinition workflow = findWorkflow(orgId, id);
        if (requests == null || requests.isEmpty()) {
            throw new BusinessException("At least one workflow step is required",
                    "WORKFLOW_STEPS_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        workflow.clearSteps();
        requests.stream()
                .sorted(Comparator.comparingInt(WorkflowStepRequest::stepNumber))
                .forEach(request -> workflow.addStep(toStep(orgId, request)));

        return WorkflowDefinitionResponse.from(workflowDefinitionRepository.save(workflow));
    }

    @Transactional(readOnly = true)
    public List<DocumentStateConfigResponse> listTransitions() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return documentStateConfigRepository.findByOrgIdAndIsDeletedFalseOrderByDocumentTypeAscFromStateAscToStateAsc(orgId)
                .stream()
                .map(DocumentStateConfigResponse::from)
                .toList();
    }

    private WorkflowDefinition findWorkflow(UUID orgId, UUID id) {
        return workflowDefinitionRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkflowDefinition", id));
    }

    private WorkflowStep toStep(UUID orgId, WorkflowStepRequest request) {
        if ((request.approverRole() == null || request.approverRole().isBlank())
                && request.approverUserId() == null) {
            throw new BusinessException("Workflow step requires approver role or user",
                    "WORKFLOW_APPROVER_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (request.stepNumber() <= 0) {
            throw new BusinessException("Workflow step number must be positive",
                    "WORKFLOW_STEP_INVALID", HttpStatus.BAD_REQUEST);
        }

        WorkflowStep step = WorkflowStep.builder()
                .stepNumber(request.stepNumber())
                .approverRole(blankToNull(request.approverRole()))
                .approverUserId(request.approverUserId())
                .timeoutHours(request.timeoutHours() != null ? request.timeoutHours() : 24)
                .onTimeout(blankToDefault(request.onTimeout(), "ESCALATE"))
                .build();
        step.setOrgId(orgId);
        return step;
    }

    private void validateJson(String json) {
        try {
            objectMapper.readTree(json);
        } catch (Exception e) {
            throw new BusinessException("Workflow trigger condition must be valid JSON",
                    "WORKFLOW_CONDITION_INVALID", HttpStatus.BAD_REQUEST);
        }
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private String blankToDefault(String value, String defaultValue) {
        return value == null || value.isBlank() ? defaultValue : value.trim();
    }
}
