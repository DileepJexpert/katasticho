package com.katasticho.erp.common.event;

import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DomainEventProcessor {

    static final int MAX_RETRY_COUNT = 5;

    private final DomainEventRepository eventRepository;
    private final List<DomainEventHandler> handlers;
    private final EntityManager entityManager;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processOne(DomainEvent event) {
        if (event.getRetryCount() >= MAX_RETRY_COUNT) {
            event.setDeadLetter(true);
            eventRepository.save(event);
            log.error("Domain event {} moved to dead letter after {} retries. Last error: {}",
                    event.getId(), event.getRetryCount(), event.getProcessingError());
            return;
        }

        for (DomainEventHandler handler : handlers) {
            if (handler.supports(event.getEventType())) {
                handler.handle(event);
            }
        }
        // Force any deferred handler INSERT (BaseEntity UUID ids don't flush at
        // save time) to surface HERE, inside the tx body, so a constraint failure
        // propagates to the worker's catch → markFailed (a fresh tx). If the
        // failure only surfaced at commit — after this method returned — it would
        // escape the try, roll back the retry bump, and the worker loop would
        // head-of-line-block the whole queue forever.
        entityManager.flush();
        event.setProcessed(true);
        event.setProcessedAt(Instant.now());
        event.setProcessingError(null);
        eventRepository.save(event);
    }

    /**
     * Record a processing failure in a SEPARATE transaction (started after the
     * business tx rolled back), so the retry bump / dead-letter flip survives the
     * poison write instead of being rolled back with it.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void markFailed(UUID eventId, String error) {
        eventRepository.findById(eventId).ifPresent(event -> {
            event.setRetryCount(event.getRetryCount() + 1);
            event.setProcessingError(error);
            if (event.getRetryCount() >= MAX_RETRY_COUNT) {
                event.setDeadLetter(true);
                log.error("Domain event {} dead-lettered after {} retries: {}",
                        eventId, event.getRetryCount(), error);
            } else {
                log.warn("Domain event {} failed (retry {}): {}", eventId, event.getRetryCount(), error);
            }
            eventRepository.save(event);
        });
    }
}
