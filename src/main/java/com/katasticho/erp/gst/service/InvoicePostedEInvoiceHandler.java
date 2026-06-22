package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.event.DomainEventHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Watches INVOICE_POSTED events and flags B2B invoices that need an IRN
 * (when the org has e-invoicing enabled) — without touching the posting flow.
 *
 * <p>The India IRN/INV-01 schema is India-specific, so this is country-guarded.
 * A Gulf org's PINT-AE e-invoicing will be wired through a separate provider
 * (see docs/INTERNATIONALIZATION_PLAN.md §10), not this handler.
 */
@Component
@RequiredArgsConstructor
public class InvoicePostedEInvoiceHandler implements DomainEventHandler {

    private static final String EVENT_TYPE = "INVOICE_POSTED";

    private final EInvoiceService eInvoiceService;
    private final CountryAccessService countryAccessService;

    @Override
    public boolean supports(String eventType) {
        return EVENT_TYPE.equals(eventType);
    }

    @Override
    public void handle(DomainEvent event) {
        if (!"IN".equals(countryAccessService.countryOf(event.getOrgId()))) {
            return; // India IRN is country-specific; Gulf uses PINT-AE
        }
        eInvoiceService.detectForInvoice(event.getOrgId(), event.getEntityId());
    }
}
