package com.katasticho.erp.common.event;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
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

    private DomainEventProcessor processor;

    @BeforeEach
    void setUp() {
        processor = new DomainEventProcessor(eventRepository, List.of(handlerA, handlerB));
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
        verify(eventRepository).save(event);
    }

    @Test
    void processOneIncrementsRetryCountOnFailure() {
        DomainEvent event = event("INVOICE_POSTED", 2);
        when(handlerA.supports("INVOICE_POSTED")).thenReturn(true);
        doThrow(new RuntimeException("db timeout")).when(handlerA).handle(event);

        processor.processOne(event);

        assertThat(event.isProcessed()).isFalse();
        assertThat(event.getRetryCount()).isEqualTo(3);
        assertThat(event.getProcessingError()).isEqualTo("db timeout");
        assertThat(event.isDeadLetter()).isFalse();
        verify(eventRepository).save(event);
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
