package com.katasticho.erp.common.event;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DomainEventPublisher {

    private final DomainEventRepository eventRepository;

    @Transactional
    public DomainEvent publish(String eventType, String entityType, UUID entityId, Map<String, Object> payload) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED", HttpStatus.FORBIDDEN);
        }

        return eventRepository.save(DomainEvent.builder()
                .orgId(orgId)
                .eventType(eventType)
                .entityType(entityType)
                .entityId(entityId)
                .payload(payload == null ? Map.of() : payload)
                .processed(false)
                .retryCount(0)
                .createdAt(Instant.now())
                .build());
    }
}
