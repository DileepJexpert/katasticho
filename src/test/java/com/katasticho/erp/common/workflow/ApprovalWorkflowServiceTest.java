package com.katasticho.erp.common.workflow;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ApprovalWorkflowServiceTest {

    @Mock private WorkflowDefinitionRepository workflowDefinitionRepository;
    @Mock private WorkflowStepRepository workflowStepRepository;
    @Mock private ApprovalRequestRepository approvalRequestRepository;
    @Mock private ApprovalDecisionRepository approvalDecisionRepository;
    @Mock private ApprovalWorkflowHandler handler;

    private ApprovalWorkflowService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new ApprovalWorkflowService(
                workflowDefinitionRepository,
                workflowStepRepository,
                approvalRequestRepository,
                approvalDecisionRepository,
                new ObjectMapper(),
                List.of(handler));

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        TenantContext.setCurrentRole("OWNER");
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void findMatchingWorkflow_evaluatesValueFieldCondition() {
        WorkflowDefinition workflow = workflow();
        when(workflowDefinitionRepository
                .findByOrgIdAndDocumentTypeAndActiveTrueAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "SALES_ORDER"))
                .thenReturn(List.of(workflow));

        Optional<WorkflowDefinition> result = service.findMatchingWorkflow(
                orgId,
                "SALES_ORDER",
                Map.of(
                        "credit.exposureAmount", new BigDecimal("1200"),
                        "credit.creditLimit", new BigDecimal("1000")));

        assertTrue(result.isPresent());
        assertEquals(workflow.getId(), result.get().getId());
    }

    @Test
    void approve_finalStep_marksRequestApprovedAndCallsDomainHandler() {
        WorkflowDefinition workflow = workflow();
        ApprovalRequest request = ApprovalRequest.builder()
                .workflowDefinition(workflow)
                .documentType("SALES_ORDER")
                .documentId(UUID.randomUUID())
                .currentStep((short) 1)
                .status(ApprovalStatus.PENDING)
                .build();
        request.setId(UUID.randomUUID());
        request.setOrgId(orgId);

        WorkflowStep step = WorkflowStep.builder()
                .workflowDefinition(workflow)
                .stepNumber((short) 1)
                .approverRole("OWNER")
                .build();
        step.setId(UUID.randomUUID());
        step.setOrgId(orgId);

        when(approvalRequestRepository.findByIdAndOrgIdAndIsDeletedFalse(request.getId(), orgId))
                .thenReturn(Optional.of(request));
        when(workflowStepRepository.findFirstByWorkflowDefinition_IdAndStepNumberAndIsDeletedFalse(
                workflow.getId(), (short) 1))
                .thenReturn(Optional.of(step));
        when(workflowStepRepository.findFirstByWorkflowDefinition_IdAndStepNumberGreaterThanAndIsDeletedFalseOrderByStepNumberAsc(
                workflow.getId(), (short) 1))
                .thenReturn(Optional.empty());
        when(approvalRequestRepository.save(any(ApprovalRequest.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(handler.documentType()).thenReturn("SALES_ORDER");

        ApprovalRequestResponse response = service.approve(request.getId(), "ok");

        assertEquals(ApprovalStatus.APPROVED, response.status());
        assertNotNull(response.resolvedAt());
        verify(approvalDecisionRepository).save(any(ApprovalDecision.class));
        verify(handler).onApproved(request);
    }

    @Test
    void findForDocument_defaultsToPendingRequest() {
        WorkflowDefinition workflow = workflow();
        UUID documentId = UUID.randomUUID();
        ApprovalRequest request = ApprovalRequest.builder()
                .workflowDefinition(workflow)
                .documentType("SALES_ORDER")
                .documentId(documentId)
                .currentStep((short) 1)
                .status(ApprovalStatus.PENDING)
                .build();
        request.setId(UUID.randomUUID());
        request.setOrgId(orgId);

        when(approvalRequestRepository
                .findFirstByOrgIdAndDocumentTypeAndDocumentIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, "SALES_ORDER", documentId, ApprovalStatus.PENDING))
                .thenReturn(Optional.of(request));

        Optional<ApprovalRequestResponse> result =
                service.findForDocument("SALES_ORDER", documentId, null);

        assertTrue(result.isPresent());
        assertEquals(request.getId(), result.get().id());
    }

    @Test
    void historyForDocument_returnsRequestsAndDecisions() {
        WorkflowDefinition workflow = workflow();
        UUID documentId = UUID.randomUUID();
        ApprovalRequest request = ApprovalRequest.builder()
                .workflowDefinition(workflow)
                .documentType("SALES_ORDER")
                .documentId(documentId)
                .currentStep((short) 1)
                .status(ApprovalStatus.APPROVED)
                .build();
        request.setId(UUID.randomUUID());
        request.setOrgId(orgId);

        ApprovalDecision decision = ApprovalDecision.builder()
                .approvalRequest(request)
                .stepNumber((short) 1)
                .decision(ApprovalStatus.APPROVED)
                .note("ok")
                .decidedBy(userId)
                .decidedAt(java.time.Instant.now())
                .build();
        decision.setId(UUID.randomUUID());
        decision.setOrgId(orgId);

        when(approvalRequestRepository.findByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalseOrderByCreatedAtDesc(
                orgId, "SALES_ORDER", documentId))
                .thenReturn(List.of(request));
        when(approvalDecisionRepository.findByOrgIdAndApprovalRequest_IdInAndIsDeletedFalseOrderByDecidedAtAsc(
                orgId, List.of(request.getId())))
                .thenReturn(List.of(decision));

        ApprovalHistoryResponse result = service.historyForDocument("SALES_ORDER", documentId);

        assertEquals(1, result.requests().size());
        assertEquals(1, result.decisions().size());
        assertEquals(ApprovalStatus.APPROVED, result.decisions().getFirst().decision());
    }

    private WorkflowDefinition workflow() {
        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code("SALES_ORDER_CREDIT_APPROVAL")
                .name("Sales Order Credit Approval")
                .documentType("SALES_ORDER")
                .triggerCondition("""
                        {"field":"credit.exposureAmount","operator":"GT","valueField":"credit.creditLimit"}
                        """)
                .active(true)
                .build();
        workflow.setId(UUID.randomUUID());
        workflow.setOrgId(orgId);
        return workflow;
    }
}
