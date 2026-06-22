package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.event.DomainEventHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Watches INVOICE_POSTED events and flags invoices that cross the e-way bill
 * threshold — the "₹50,000 before transit" mandate — without touching the
 * invoice posting flow itself.
 *
 * <p>e-way bills are an India-only construct, and this handler fires by DEFAULT
 * (the ₹50k threshold applies even without explicit opt-in), so it is guarded by
 * country: a Gulf org posting a large invoice must NOT get an India e-way-bill row.
 */
@Component
@RequiredArgsConstructor
public class InvoicePostedEwayBillHandler implements DomainEventHandler {

    private static final String EVENT_TYPE = "INVOICE_POSTED";

    private final EwayBillService ewayBillService;
    private final CountryAccessService countryAccessService;

    @Override
    public boolean supports(String eventType) {
        return EVENT_TYPE.equals(eventType);
    }

    @Override
    public void handle(DomainEvent event) {
        if (!"IN".equals(countryAccessService.countryOf(event.getOrgId()))) {
            return; // e-way bills are India-only
        }
        ewayBillService.detectForInvoice(event.getOrgId(), event.getEntityId());
    }
}
