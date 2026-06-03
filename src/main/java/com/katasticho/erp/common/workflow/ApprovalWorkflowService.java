package com.katasticho.erp.common.workflow;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ApprovalWorkflowService {

    private final WorkflowDefinitionRepository workflowDefinitionRepository;
    private final WorkflowStepRepository workflowStepRepository;
    private final ApprovalRequestRepository approvalRequestRepository;
    private final ApprovalDecisionRepository approvalDecisionRepository;
    private final ObjectMapper objectMapper;
    private final List<ApprovalWorkflowHandler> handlers;

    @Transactional(readOnly = true)
    public Optional<WorkflowDefinition> findMatchingWorkflow(
            UUID orgId,
            String documentType,
            Map<String, Object> context
    ) {
        return workflowDefinitionRepository
                .findByOrgIdAndDocumentTypeAndActiveTrueAndIsDeletedFalseOrderByCreatedAtAsc(orgId, documentType)
                .stream()
                .filter(workflow -> matches(workflow.getTriggerCondition(), context))
                .findFirst();
    }

    @Transactional
    public ApprovalRequest requestApproval(
            UUID orgId,
            WorkflowDefinition workflow,
            String documentType,
            UUID documentId,
            String triggerReason,
            Map<String, Object> context
    ) {
        return approvalRequestRepository
                .findFirstByOrgIdAndWorkflowDefinition_IdAndDocumentTypeAndDocumentIdAndStatusAndIsDeletedFalse(
                        orgId, workflow.getId(), documentType, documentId, ApprovalStatus.PENDING)
                .orElseGet(() -> {
                    ApprovalRequest request = ApprovalRequest.builder()
                            .workflowDefinition(workflow)
                            .documentType(documentType)
                            .documentId(documentId)
                            .currentStep((short) 1)
                            .triggerReason(triggerReason)
                            .contextJson(toJson(context))
                            .status(ApprovalStatus.PENDING)
                            .requestedBy(TenantContext.getCurrentUserId())
                            .requestedAt(Instant.now())
                            .build();
                    request.setOrgId(orgId);
                    return approvalRequestRepository.save(request);
                });
    }

    @Transactional(readOnly = true)
    public Page<ApprovalRequestResponse> list(ApprovalStatus status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<ApprovalRequest> page = status == null
                ? approvalRequestRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                : approvalRequestRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pageable);
        return page.map(ApprovalRequestResponse::from);
    }

    @Transactional(readOnly = true)
    public ApprovalRequestResponse get(UUID id) {
        return ApprovalRequestResponse.from(findRequest(id));
    }

    @Transactional(readOnly = true)
    public Optional<ApprovalRequestResponse> findForDocument(
            String documentType,
            UUID documentId,
            ApprovalStatus status
    ) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ApprovalStatus effectiveStatus = status != null ? status : ApprovalStatus.PENDING;
        return approvalRequestRepository
                .findFirstByOrgIdAndDocumentTypeAndDocumentIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, documentType, documentId, effectiveStatus)
                .map(ApprovalRequestResponse::from);
    }

    @Transactional(readOnly = true)
    public ApprovalHistoryResponse historyForDocument(String documentType, UUID documentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<ApprovalRequest> requests =
                approvalRequestRepository.findByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, documentType, documentId);
        if (requests.isEmpty()) {
            return new ApprovalHistoryResponse(List.of(), List.of());
        }

        List<UUID> requestIds = requests.stream().map(ApprovalRequest::getId).toList();
        List<ApprovalDecision> decisions =
                approvalDecisionRepository.findByOrgIdAndApprovalRequest_IdInAndIsDeletedFalseOrderByDecidedAtAsc(
                        orgId, requestIds);
        return new ApprovalHistoryResponse(
                requests.stream().map(ApprovalRequestResponse::from).toList(),
                decisions.stream().map(ApprovalDecisionResponse::from).toList());
    }

    @Transactional
    public ApprovalRequestResponse approve(UUID id, String note) {
        ApprovalRequest request = decide(id, ApprovalStatus.APPROVED, note);
        return ApprovalRequestResponse.from(request);
    }

    @Transactional
    public ApprovalRequestResponse reject(UUID id, String note) {
        ApprovalRequest request = decide(id, ApprovalStatus.REJECTED, note);
        return ApprovalRequestResponse.from(request);
    }

    private ApprovalRequest decide(UUID id, ApprovalStatus decision, String note) {
        ApprovalRequest request = findRequest(id);
        if (request.getStatus() != ApprovalStatus.PENDING) {
            throw new BusinessException("Approval request is not pending",
                    "WORKFLOW_APPROVAL_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }

        WorkflowDefinition workflow = request.getWorkflowDefinition();
        WorkflowStep currentStep = workflowStepRepository
                .findFirstByWorkflowDefinition_IdAndStepNumberAndIsDeletedFalse(workflow.getId(), request.getCurrentStep())
                .orElseThrow(() -> new BusinessException(
                        "Approval workflow has no current step",
                        "WORKFLOW_STEP_MISSING",
                        HttpStatus.BAD_REQUEST));

        ensureApproverCanDecide(currentStep);
        ensureRequesterCannotApproveOwnRequest(request);

        approvalDecisionRepository.save(ApprovalDecision.builder()
                .approvalRequest(request)
                .stepNumber(request.getCurrentStep())
                .decision(decision)
                .note(note)
                .decidedBy(TenantContext.getCurrentUserId())
                .decidedAt(Instant.now())
                .build());

        if (decision == ApprovalStatus.REJECTED) {
            request.setStatus(ApprovalStatus.REJECTED);
            request.setResolvedAt(Instant.now());
            request = approvalRequestRepository.save(request);
            handlerFor(request).onRejected(request);
            return request;
        }

        Optional<WorkflowStep> nextStep = workflowStepRepository
                .findFirstByWorkflowDefinition_IdAndStepNumberGreaterThanAndIsDeletedFalseOrderByStepNumberAsc(
                        workflow.getId(), request.getCurrentStep());
        if (nextStep.isPresent()) {
            request.setCurrentStep(nextStep.get().getStepNumber());
            return approvalRequestRepository.save(request);
        }

        request.setStatus(ApprovalStatus.APPROVED);
        request.setResolvedAt(Instant.now());
        request = approvalRequestRepository.save(request);
        handlerFor(request).onApproved(request);
        return request;
    }

    private ApprovalRequest findRequest(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return approvalRequestRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ApprovalRequest", id));
    }

    private void ensureApproverCanDecide(WorkflowStep step) {
        UUID userId = TenantContext.getCurrentUserId();
        String role = TenantContext.getCurrentRole();

        if (step.getApproverUserId() != null) {
            if (!step.getApproverUserId().equals(userId)) {
                throw new BusinessException("You are not allowed to approve this step",
                        "WORKFLOW_APPROVER_FORBIDDEN", HttpStatus.FORBIDDEN);
            }
            return;
        }

        if (step.getApproverRole() == null || !step.getApproverRole().equals(role)) {
            throw new BusinessException("You are not allowed to approve this step",
                    "WORKFLOW_APPROVER_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
    }

    private void ensureRequesterCannotApproveOwnRequest(ApprovalRequest request) {
        UUID userId = TenantContext.getCurrentUserId();
        if (request.getRequestedBy() != null && request.getRequestedBy().equals(userId)) {
            throw new BusinessException("You cannot approve your own request",
                    "WORKFLOW_SELF_APPROVAL_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
    }

    private ApprovalWorkflowHandler handlerFor(ApprovalRequest request) {
        Map<String, ApprovalWorkflowHandler> byDocumentType = handlers.stream()
                .collect(Collectors.toMap(ApprovalWorkflowHandler::documentType, Function.identity(), (a, b) -> a));
        ApprovalWorkflowHandler handler = byDocumentType.get(request.getDocumentType());
        if (handler == null) {
            throw new BusinessException("No workflow handler for " + request.getDocumentType(),
                    "WORKFLOW_HANDLER_MISSING", HttpStatus.BAD_REQUEST);
        }
        return handler;
    }

    private boolean matches(String triggerCondition, Map<String, Object> context) {
        try {
            JsonNode condition = objectMapper.readTree(triggerCondition);
            return evaluate(condition, context);
        } catch (Exception e) {
            return false;
        }
    }

    private boolean evaluate(JsonNode condition, Map<String, Object> context) {
        if (condition.has("all")) {
            for (JsonNode child : condition.get("all")) {
                if (!evaluate(child, context)) {
                    return false;
                }
            }
            return true;
        }

        if (condition.has("any")) {
            for (JsonNode child : condition.get("any")) {
                if (evaluate(child, context)) {
                    return true;
                }
            }
            return false;
        }

        String field = condition.path("field").asText(null);
        String operator = condition.path("operator").asText(null);
        if (field == null || operator == null) {
            return false;
        }

        Object actual = context.get(field);
        Object expected = condition.has("valueField")
                ? context.get(condition.get("valueField").asText())
                : jsonValue(condition.get("value"));

        return compare(actual, operator, expected);
    }

    private Object jsonValue(JsonNode node) {
        if (node == null || node.isNull()) {
            return null;
        }
        if (node.isNumber()) {
            return node.decimalValue();
        }
        if (node.isBoolean()) {
            return node.booleanValue();
        }
        return node.asText();
    }

    private boolean compare(Object actual, String operator, Object expected) {
        if (actual == null || expected == null) {
            return false;
        }

        BigDecimal left = asBigDecimal(actual);
        BigDecimal right = asBigDecimal(expected);
        if (left != null && right != null) {
            int cmp = left.compareTo(right);
            return switch (operator) {
                case "GT", ">" -> cmp > 0;
                case "GTE", ">=" -> cmp >= 0;
                case "LT", "<" -> cmp < 0;
                case "LTE", "<=" -> cmp <= 0;
                case "EQ", "=" -> cmp == 0;
                case "NEQ", "!=" -> cmp != 0;
                default -> false;
            };
        }

        return switch (operator) {
            case "EQ", "=" -> Objects.equals(String.valueOf(actual), String.valueOf(expected));
            case "NEQ", "!=" -> !Objects.equals(String.valueOf(actual), String.valueOf(expected));
            default -> false;
        };
    }

    private BigDecimal asBigDecimal(Object value) {
        if (value instanceof BigDecimal decimal) {
            return decimal;
        }
        if (value instanceof Number number) {
            return BigDecimal.valueOf(number.doubleValue());
        }
        try {
            return new BigDecimal(String.valueOf(value));
        } catch (Exception e) {
            return null;
        }
    }

    private String toJson(Map<String, Object> context) {
        try {
            return objectMapper.writeValueAsString(context);
        } catch (JsonProcessingException e) {
            return "{}";
        }
    }
}
