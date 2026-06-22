package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.common.event.DomainEvent;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Guards the two INVOICE_POSTED handlers (e-way bill + e-invoice IRN) against
 * firing for non-India orgs — these are India-only constructs and the e-way
 * handler fires by default (₹50k threshold) even without opt-in.
 */
@ExtendWith(MockitoExtension.class)
class InvoicePostedHandlerCountryGuardTest {

    @Mock private EwayBillService ewayBillService;
    @Mock private EInvoiceService eInvoiceService;
    @Mock private CountryAccessService countryAccessService;

    private final UUID orgId = UUID.randomUUID();
    private final UUID invoiceId = UUID.randomUUID();

    private DomainEvent event() {
        DomainEvent e = new DomainEvent();
        e.setOrgId(orgId);
        e.setEntityId(invoiceId);
        return e;
    }

    @Test
    void eway_handler_skips_gulf_org() {
        when(countryAccessService.countryOf(orgId)).thenReturn("AE");
        new InvoicePostedEwayBillHandler(ewayBillService, countryAccessService).handle(event());
        verify(ewayBillService, never()).detectForInvoice(any(), any());
    }

    @Test
    void eway_handler_runs_for_india_org() {
        when(countryAccessService.countryOf(orgId)).thenReturn("IN");
        new InvoicePostedEwayBillHandler(ewayBillService, countryAccessService).handle(event());
        verify(ewayBillService).detectForInvoice(orgId, invoiceId);
    }

    @Test
    void einvoice_handler_skips_gulf_org() {
        when(countryAccessService.countryOf(orgId)).thenReturn("OM");
        new InvoicePostedEInvoiceHandler(eInvoiceService, countryAccessService).handle(event());
        verify(eInvoiceService, never()).detectForInvoice(any(), any());
    }

    @Test
    void einvoice_handler_runs_for_india_org() {
        when(countryAccessService.countryOf(orgId)).thenReturn("IN");
        new InvoicePostedEInvoiceHandler(eInvoiceService, countryAccessService).handle(event());
        verify(eInvoiceService).detectForInvoice(orgId, invoiceId);
    }
}
