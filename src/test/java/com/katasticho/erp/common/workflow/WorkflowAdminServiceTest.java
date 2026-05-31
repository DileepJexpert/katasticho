package com.katasticho.erp.common.workflow;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkflowAdminServiceTest {

    @Mock private WorkflowDefinitionRepository workflowDefinitionRepository;
    @Mock private DocumentStateConfigRepository documentStateConfigRepository;

    private WorkflowAdminService service;
    private UUID orgId;
    private WorkflowDefinition workflow;

    @BeforeEach
    void setUp() {
        service = new WorkflowAdminService(
                workflowDefinitionRepository,
                documentStateConfigRepository,
                new ObjectMapper());

        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);

        workflow = WorkflowDefinition.builder()
                .code("SALES_ORDER_CREDIT_APPROVAL")
                .name("Sales Order Credit Approval")
                .documentType("SALES_ORDER")
                .triggerCondition("""
                        {"field":"credit.exposureAmount","operator":"GT","valueField":"credit.creditLimit"}
                        """)
                .active(false)
                .build();
        workflow.setId(UUID.randomUUID());
        workflow.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void updateWorkflow_rejectsInvalidTriggerJson() {
        when(workflowDefinitionRepository.findByIdAndOrgIdAndIsDeletedFalse(workflow.getId(), orgId))
                .thenReturn(Optional.of(workflow));

        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.updateWorkflow(workflow.getId(), new WorkflowUpdateRequest(true, "{broken")));

        assertEquals("WORKFLOW_CONDITION_INVALID", ex.getErrorCode());
    }

    @Test
    void replaceSteps_requiresApproverRoleOrUser() {
        when(workflowDefinitionRepository.findByIdAndOrgIdAndIsDeletedFalse(workflow.getId(), orgId))
                .thenReturn(Optional.of(workflow));

        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.replaceSteps(workflow.getId(), List.of(
                        new WorkflowStepRequest((short) 1, " ", null, null, null))));

        assertEquals("WORKFLOW_APPROVER_REQUIRED", ex.getErrorCode());
    }

    @Test
    void replaceSteps_sortsAndNormalizesSteps() {
        when(workflowDefinitionRepository.findByIdAndOrgIdAndIsDeletedFalse(workflow.getId(), orgId))
                .thenReturn(Optional.of(workflow));
        when(workflowDefinitionRepository.save(any(WorkflowDefinition.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        WorkflowDefinitionResponse response = service.replaceSteps(workflow.getId(), List.of(
                new WorkflowStepRequest((short) 2, "ADMIN", null, (short) 12, "REJECT"),
                new WorkflowStepRequest((short) 1, " OWNER ", null, null, " ")));

        assertEquals(2, response.steps().size());
        assertEquals((short) 1, response.steps().get(0).stepNumber());
        assertEquals("OWNER", response.steps().get(0).approverRole());
        assertEquals((short) 24, response.steps().get(0).timeoutHours());
        assertEquals("ESCALATE", response.steps().get(0).onTimeout());
        assertEquals((short) 2, response.steps().get(1).stepNumber());
        assertEquals("ADMIN", response.steps().get(1).approverRole());
        assertEquals("REJECT", response.steps().get(1).onTimeout());
    }
}
