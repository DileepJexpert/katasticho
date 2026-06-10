package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.event.DomainEventHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Watches INVOICE_POSTED events and flags invoices that cross the e-way bill
 * threshold — the "₹50,000 before transit" mandate — without touching the
 * invoice posting flow itself.
 */
@Component
@RequiredArgsConstructor
public class InvoicePostedEwayBillHandler implements DomainEventHandler {

    private static final String EVENT_TYPE = "INVOICE_POSTED";

    private final EwayBillService ewayBillService;

    @Override
    public boolean supports(String eventType) {
        return EVENT_TYPE.equals(eventType);
    }

    @Override
    public void handle(DomainEvent event) {
        ewayBillService.detectForInvoice(event.getOrgId(), event.getEntityId());
    }
}
