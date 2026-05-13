package com.katasticho.erp.common.event;

import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DomainEventPublisherTest {

    @Mock
    private DomainEventRepository eventRepository;

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void publishStoresTenantScopedUnprocessedEvent() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);

        DomainEventPublisher publisher = new DomainEventPublisher(eventRepository);
        when(eventRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        DomainEvent event = publisher.publish("INVOICE_POSTED", "INVOICE", invoiceId, Map.of("number", "INV-1"));

        assertThat(event.getOrgId()).isEqualTo(orgId);
        assertThat(event.getEventType()).isEqualTo("INVOICE_POSTED");
        assertThat(event.getEntityType()).isEqualTo("INVOICE");
        assertThat(event.getEntityId()).isEqualTo(invoiceId);
        assertThat(event.isProcessed()).isFalse();
        assertThat(event.getRetryCount()).isZero();
        assertThat(event.getPayload()).containsEntry("number", "INV-1");

        ArgumentCaptor<DomainEvent> captor = ArgumentCaptor.forClass(DomainEvent.class);
        verify(eventRepository).save(captor.capture());
        assertThat(captor.getValue().getCreatedAt()).isNotNull();
    }
}
