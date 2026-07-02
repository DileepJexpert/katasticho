package com.katasticho.erp.common.event;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class DomainEventWorker {

    private static final int BATCH_SIZE = 50;

    private final DomainEventRepository eventRepository;
    private final DomainEventProcessor eventProcessor;

    @Scheduled(fixedDelayString = "${app.domain-events.worker-delay-ms:30000}")
    @SchedulerLock(name = "DomainEventWorker", lockAtMostFor = "PT5M", lockAtLeastFor = "PT10S")
    public void processPendingEvents() {
        List<DomainEvent> events = eventRepository.findByProcessedFalseAndDeadLetterFalseOrderByCreatedAtAsc(
                PageRequest.of(0, BATCH_SIZE));
        for (DomainEvent event : events) {
            eventProcessor.processOne(event);
        }
    }
}
