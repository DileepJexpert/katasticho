package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.entity.DomainEvent;
import com.katasticho.erp.ai.repository.DomainEventRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DomainEventService {

    private final DomainEventRepository domainEventRepository;

    @Transactional
    public DomainEvent record(String eventType, String entityType, UUID entityId, Map<String, Object> payload) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }

        UUID userId = TenantContext.getCurrentUserId();
        DomainEvent event = DomainEvent.builder()
                .orgId(orgId)
                .eventType(eventType)
                .entityType(entityType)
                .entityId(entityId)
                .payload(payload != null ? payload : Map.of())
                .actorType(userId != null ? "USER" : "SYSTEM")
                .actorId(userId != null ? userId.toString() : null)
                .build();
        return domainEventRepository.save(event);
    }
}
