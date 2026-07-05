package com.katasticho.erp.common.event;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageRequest;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DomainEventWorkerTest {

    @Mock
    private DomainEventRepository eventRepository;

    @Mock
    private DomainEventProcessor eventProcessor;

    @InjectMocks
    private DomainEventWorker worker;

    @Test
    void processesBatchOfFiveEventsSuccessfully() {
        List<DomainEvent> events = List.of(
                event("EVT_A"), event("EVT_B"), event("EVT_C"),
                event("EVT_D"), event("EVT_E"));
        when(eventRepository.findByProcessedFalseAndDeadLetterFalseOrderByCreatedAtAsc(any()))
                .thenReturn(events);

        worker.processPendingEvents();

        verify(eventProcessor, times(5)).processOne(any(DomainEvent.class));
        for (DomainEvent e : events) {
            verify(eventProcessor).processOne(e);
        }
    }

    @Test
    void allEventsArePassedToProcessorEvenIfOneFailsInternally() {
        List<DomainEvent> events = List.of(
                event("EVT_1"), event("EVT_2"), event("EVT_3"),
                event("EVT_4"), event("EVT_5"));
        when(eventRepository.findByProcessedFalseAndDeadLetterFalseOrderByCreatedAtAsc(any()))
                .thenReturn(events);

        worker.processPendingEvents();

        verify(eventProcessor, times(5)).processOne(any(DomainEvent.class));
        verify(eventProcessor).processOne(events.get(0));
        verify(eventProcessor).processOne(events.get(1));
        verify(eventProcessor).processOne(events.get(2));
        verify(eventProcessor).processOne(events.get(3));
        verify(eventProcessor).processOne(events.get(4));
    }

    @Test
    void poisonEventIsMarkedFailedAndBatchContinues() {
        List<DomainEvent> events = List.of(event("EVT_1"), event("EVT_2"), event("EVT_3"));
        when(eventRepository.findByProcessedFalseAndDeadLetterFalseOrderByCreatedAtAsc(any()))
                .thenReturn(events);
        // The middle event's processOne throws (its REQUIRES_NEW tx rolled back);
        // the worker must record the failure in a fresh tx and keep going.
        doThrow(new RuntimeException("boom")).when(eventProcessor).processOne(events.get(1));

        worker.processPendingEvents();

        verify(eventProcessor, times(3)).processOne(any(DomainEvent.class));
        verify(eventProcessor).markFailed(events.get(1).getId(), "boom");
        verify(eventProcessor).processOne(events.get(2)); // batch not aborted
    }

    @Test
    void emptyBatchCompletesWithoutErrors() {
        when(eventRepository.findByProcessedFalseAndDeadLetterFalseOrderByCreatedAtAsc(
                PageRequest.of(0, 50))).thenReturn(List.of());

        worker.processPendingEvents();

        verifyNoInteractions(eventProcessor);
    }

    private DomainEvent event(String eventType) {
        return DomainEvent.builder()
                .id(UUID.randomUUID())
                .orgId(UUID.randomUUID())
                .eventType(eventType)
                .entityType("INVOICE")
                .entityId(UUID.randomUUID())
                .processed(false)
                .deadLetter(false)
                .retryCount(0)
                .createdAt(Instant.now())
                .build();
    }
}
