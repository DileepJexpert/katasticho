package com.katasticho.erp.common.event;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class DomainEventProcessor {

    static final int MAX_RETRY_COUNT = 5;

    private final DomainEventRepository eventRepository;
    private final List<DomainEventHandler> handlers;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processOne(DomainEvent event) {
        if (event.getRetryCount() >= MAX_RETRY_COUNT) {
            event.setDeadLetter(true);
            eventRepository.save(event);
            log.error("Domain event {} moved to dead letter after {} retries. Last error: {}",
                    event.getId(), event.getRetryCount(), event.getProcessingError());
            return;
        }

        try {
            for (DomainEventHandler handler : handlers) {
                if (handler.supports(event.getEventType())) {
                    handler.handle(event);
                }
            }
            event.setProcessed(true);
            event.setProcessedAt(Instant.now());
            event.setProcessingError(null);
        } catch (Exception e) {
            event.setRetryCount(event.getRetryCount() + 1);
            event.setProcessingError(e.getMessage());
            log.warn("Domain event {} failed (retry {}): {}", event.getId(), event.getRetryCount(), e.getMessage());
        }
        eventRepository.save(event);
    }
}
