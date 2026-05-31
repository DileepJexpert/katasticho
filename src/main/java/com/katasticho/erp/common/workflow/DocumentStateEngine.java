package com.katasticho.erp.common.workflow;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DocumentStateEngine {

    private final DocumentStateConfigRepository configRepository;

    @Transactional(readOnly = true)
    public DocumentStateConfig validateTransition(
            UUID orgId,
            String documentType,
            String fromState,
            String toState
    ) {
        DocumentStateConfig config = configRepository
                .findByOrgIdAndDocumentTypeAndFromStateAndToStateAndActiveTrueAndIsDeletedFalse(
                        orgId, documentType, fromState, toState)
                .orElseThrow(() -> new BusinessException(
                        "Cannot move " + documentType + " from " + fromState + " to " + toState,
                        "DOC_INVALID_STATE_TRANSITION",
                        HttpStatus.BAD_REQUEST));

        String role = TenantContext.getCurrentRole();
        if (role != null && config.getAllowedRoles() != null
                && Arrays.stream(config.getAllowedRoles()).noneMatch(role::equals)) {
            throw new BusinessException(
                    role + " cannot move " + documentType + " from " + fromState + " to " + toState,
                    "DOC_TRANSITION_FORBIDDEN",
                    HttpStatus.FORBIDDEN);
        }

        return config;
    }
}
