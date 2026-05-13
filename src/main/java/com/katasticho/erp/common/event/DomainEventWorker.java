package com.katasticho.erp.common.event;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class DomainEventWorker {

    private static final int BATCH_SIZE = 50;

    private final DomainEventRepository eventRepository;
    private final List<DomainEventHandler> handlers;

    @Scheduled(fixedDelayString = "${app.domain-events.worker-delay-ms:30000}")
    @Transactional
    public void processPendingEvents() {
        List<DomainEvent> events = eventRepository.findByProcessedFalseOrderByCreatedAtAsc(PageRequest.of(0, BATCH_SIZE));
        for (DomainEvent event : events) {
            processOne(event);
        }
    }

    private void processOne(DomainEvent event) {
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
            log.warn("Domain event {} failed: {}", event.getId(), e.getMessage());
        }
    }
}
