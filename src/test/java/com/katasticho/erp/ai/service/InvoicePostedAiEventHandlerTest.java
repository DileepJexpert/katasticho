package com.katasticho.erp.ai.service;

import com.katasticho.erp.common.event.DomainEvent;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class InvoicePostedAiEventHandlerTest {

    private final RuleBasedAiAgentService ruleBasedAiAgentService = mock(RuleBasedAiAgentService.class);
    private final InvoicePostedAiEventHandler handler = new InvoicePostedAiEventHandler(ruleBasedAiAgentService);

    @Test
    void supportsOnlyInvoicePosted() {
        assertThat(handler.supports("INVOICE_POSTED")).isTrue();
        assertThat(handler.supports("PAYMENT_RECEIVED")).isFalse();
    }

    @Test
    void handleScansPostedInvoice() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        DomainEvent event = DomainEvent.builder()
                .orgId(orgId)
                .eventType("INVOICE_POSTED")
                .entityType("INVOICE")
                .entityId(invoiceId)
                .build();

        handler.handle(event);

        verify(ruleBasedAiAgentService).scanPostedInvoice(orgId, invoiceId);
    }
}
