package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.event.DomainEventHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Watches INVOICE_POSTED events and flags B2B invoices that need an IRN
 * (when the org has e-invoicing enabled) — without touching the posting flow.
 */
@Component
@RequiredArgsConstructor
public class InvoicePostedEInvoiceHandler implements DomainEventHandler {

    private static final String EVENT_TYPE = "INVOICE_POSTED";

    private final EInvoiceService eInvoiceService;

    @Override
    public boolean supports(String eventType) {
        return EVENT_TYPE.equals(eventType);
    }

    @Override
    public void handle(DomainEvent event) {
        eInvoiceService.detectForInvoice(event.getOrgId(), event.getEntityId());
    }
}
