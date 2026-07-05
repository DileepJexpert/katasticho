package com.katasticho.erp.common.event;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DomainEventProcessorTest {

    @Mock
    private DomainEventRepository eventRepository;

    @Mock
    private DomainEventHandler handlerA;

    @Mock
    private DomainEventHandler handlerB;

    @Mock
    private EntityManager entityManager;

    private DomainEventProcessor processor;

    @BeforeEach
    void setUp() {
        processor = new DomainEventProcessor(eventRepository, List.of(handlerA, handlerB), entityManager);
    }

    @Test
    void processOneMarksEventAsProcessedOnSuccess() {
        DomainEvent event = event("INVOICE_POSTED", 0);
        when(handlerA.supports("INVOICE_POSTED")).thenReturn(true);
        when(handlerB.supports("INVOICE_POSTED")).thenReturn(false);

        processor.processOne(event);

        assertThat(event.isProcessed()).isTrue();
        assertThat(event.getProcessedAt()).isNotNull();
        assertThat(event.getProcessingError()).isNull();
        verify(handlerA).handle(event);
        verify(handlerB, never()).handle(any());
        // A deferred handler INSERT must be forced to surface inside the tx body
        // so a constraint failure reaches the worker's catch instead of escaping
        // at commit and head-of-line-blocking the queue.
        verify(entityManager).flush();
        verify(eventRepository).save(event);
    }

    @Test
    void processOnePropagatesHandlerFailureWithoutMarkingProcessed() {
        DomainEvent event = event("INVOICE_POSTED", 2);
        when(handlerA.supports("INVOICE_POSTED")).thenReturn(true);
        doThrow(new RuntimeException("db timeout")).when(handlerA).handle(event);

        // The failure now propagates out of processOne (its REQUIRES_NEW tx rolls
        // back); the retry bump is the worker's job via markFailed in a fresh tx.
        assertThatThrownBy(() -> processor.processOne(event))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("db timeout");

        assertThat(event.isProcessed()).isFalse();
        verify(eventRepository, never()).save(event);
    }

    @Test
    void processOneMovesToDeadLetterWhenRetryCountExceeded() {
        DomainEvent event = event("INVOICE_POSTED", 5);
        event.setProcessingError("persistent failure");

        processor.processOne(event);

        assertThat(event.isDeadLetter()).isTrue();
        assertThat(event.isProcessed()).isFalse();
        assertThat(event.getRetryCount()).isEqualTo(5);
        verify(handlerA, never()).handle(any());
        verify(handlerB, never()).handle(any());
        verify(entityManager, never()).flush();
        verify(eventRepository).save(event);
    }

    @Test
    void processOneMovesToDeadLetterWhenRetryCountAboveMax() {
        DomainEvent event = event("INVOICE_POSTED", 7);
        event.setProcessingError("old failure");

        processor.processOne(event);

        assertThat(event.isDeadLetter()).isTrue();
        verify(handlerA, never()).handle(any());
        verify(eventRepository).save(event);
    }

    @Test
    void markFailedIncrementsRetryCountInSeparateTx() {
        DomainEvent event = event("INVOICE_POSTED", 2);
        when(eventRepository.findById(event.getId())).thenReturn(Optional.of(event));

        processor.markFailed(event.getId(), "db timeout");

        assertThat(event.getRetryCount()).isEqualTo(3);
        assertThat(event.getProcessingError()).isEqualTo("db timeout");
        assertThat(event.isDeadLetter()).isFalse();
        assertThat(event.isProcessed()).isFalse();
        verify(eventRepository).save(event);
    }

    @Test
    void markFailedDeadLettersWhenRetriesHitMax() {
        DomainEvent event = event("INVOICE_POSTED", 4);
        when(eventRepository.findById(event.getId())).thenReturn(Optional.of(event));

        processor.markFailed(event.getId(), "still failing");

        assertThat(event.getRetryCount()).isEqualTo(5);
        assertThat(event.isDeadLetter()).isTrue();
        verify(eventRepository).save(event);
    }

    @Test
    void markFailedNoopWhenEventGone() {
        UUID id = UUID.randomUUID();
        when(eventRepository.findById(id)).thenReturn(Optional.empty());

        processor.markFailed(id, "gone");

        verify(eventRepository, never()).save(any());
    }

    private DomainEvent event(String eventType, int retryCount) {
        return DomainEvent.builder()
                .id(UUID.randomUUID())
                .orgId(UUID.randomUUID())
                .eventType(eventType)
                .entityType("INVOICE")
                .entityId(UUID.randomUUID())
                .payload(Map.of())
                .processed(false)
                .deadLetter(false)
                .retryCount(retryCount)
                .createdAt(Instant.now())
                .build();
    }
}
