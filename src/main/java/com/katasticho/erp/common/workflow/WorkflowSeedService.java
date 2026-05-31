package com.katasticho.erp.common.workflow;

import com.katasticho.erp.common.service.SeedResult;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class WorkflowSeedService {

    private final DocumentStateConfigRepository stateConfigRepository;
    private final WorkflowDefinitionRepository workflowDefinitionRepository;

    @Transactional
    public SeedResult seedDefaultsForOrg(UUID orgId) {
        boolean created = false;

        created |= transition(orgId, "SALES_ORDER", "DRAFT", "CONFIRMED",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT", "OPERATOR"}, false);
        created |= transition(orgId, "SALES_ORDER", "PENDING_APPROVAL", "DRAFT",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);
        created |= transition(orgId, "SALES_ORDER", "PENDING_APPROVAL", "REJECTED",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);
        created |= transition(orgId, "SALES_ORDER", "DRAFT", "CANCELLED",
                new String[]{"OWNER", "ADMIN"}, false);
        created |= transition(orgId, "SALES_ORDER", "CONFIRMED", "CANCELLED",
                new String[]{"OWNER", "ADMIN"}, false);

        created |= transition(orgId, "PURCHASE_ORDER", "DRAFT", "SENT",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);
        created |= transition(orgId, "DELIVERY_CHALLAN", "DRAFT", "DISPATCHED",
                new String[]{"OWNER", "ADMIN", "OPERATOR"}, false);
        created |= transition(orgId, "INVOICE", "DRAFT", "POSTED",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);
        created |= transition(orgId, "JOURNAL_ENTRY", "DRAFT", "POSTED",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);
        created |= transition(orgId, "STOCK_ADJUSTMENT", "DRAFT", "POSTED",
                new String[]{"OWNER", "ADMIN"}, false);
        created |= transition(orgId, "CREDIT_NOTE", "DRAFT", "PENDING_APPROVAL",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);
        created |= transition(orgId, "CREDIT_NOTE", "PENDING_APPROVAL", "ISSUED",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);
        created |= transition(orgId, "CREDIT_NOTE", "PENDING_APPROVAL", "REJECTED",
                new String[]{"OWNER", "ADMIN", "ACCOUNTANT"}, false);

        created |= workflow(orgId, "SALES_ORDER",
                "SALES_ORDER_CREDIT_APPROVAL",
                "Sales Order Credit Approval",
                """
                        {"field":"credit.exposureAmount","operator":"GT","valueField":"credit.creditLimit"}
                        """);
        created |= workflow(orgId, "SALES_ORDER",
                "SALES_ORDER_OVERDUE_APPROVAL",
                "Sales Order Overdue Invoice Approval",
                """
                        {"field":"overdue.count","operator":"GT","value":0}
                        """);
        created |= workflow(orgId, "CREDIT_NOTE",
                "CREDIT_NOTE_RETURN_APPROVAL",
                "Credit Note Return Approval",
                """
                        {"field":"creditNote.totalAmount","operator":"GTE","value":5000}
                        """);

        return created ? SeedResult.CREATED_NEW : SeedResult.ALREADY_EXISTS;
    }

    private boolean transition(UUID orgId, String documentType, String fromState, String toState,
                               String[] roles, boolean requiresApproval) {
        if (stateConfigRepository.existsByOrgIdAndDocumentTypeAndFromStateAndToStateAndIsDeletedFalse(
                orgId, documentType, fromState, toState)) {
            return false;
        }

        DocumentStateConfig config = DocumentStateConfig.builder()
                .documentType(documentType)
                .fromState(fromState)
                .toState(toState)
                .allowedRoles(roles)
                .requiresApproval(requiresApproval)
                .active(true)
                .build();
        config.setOrgId(orgId);
        stateConfigRepository.save(config);
        return true;
    }

    private boolean workflow(UUID orgId, String documentType, String code, String name, String triggerCondition) {
        if (workflowDefinitionRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code).isPresent()) {
            return false;
        }

        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code(code)
                .name(name)
                .documentType(documentType)
                .triggerCondition(triggerCondition)
                .active(false)
                .build();
        workflow.setOrgId(orgId);
        WorkflowStep step = WorkflowStep.builder()
                .stepNumber((short) 1)
                .approverRole("OWNER")
                .timeoutHours((short) 24)
                .onTimeout("ESCALATE")
                .build();
        step.setOrgId(orgId);
        workflow.addStep(step);
        workflowDefinitionRepository.save(workflow);
        return true;
    }
}
