package com.katasticho.erp.ai.service;

import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.event.DomainEventHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class InvoicePostedAiEventHandler implements DomainEventHandler {

    private static final String EVENT_TYPE = "INVOICE_POSTED";

    private final RuleBasedAiAgentService ruleBasedAiAgentService;

    @Override
    public boolean supports(String eventType) {
        return EVENT_TYPE.equals(eventType);
    }

    @Override
    public void handle(DomainEvent event) {
        ruleBasedAiAgentService.scanPostedInvoice(event.getOrgId(), event.getEntityId());
    }
}
