package com.katasticho.erp.gst.einvoice;

/**
 * Country-specific e-invoice schema generator. The seam that lets India's
 * IRP/INV-01 JSON and the UAE's PINT-AE / Peppol UBL XML coexist without
 * forking the invoice flow (docs/INTERNATIONALIZATION_PLAN.md §10).
 *
 * <p>Implementations are selected by country via the org's
 * {@code CountryProfile.eInvoiceProvider()} mapping.
 */
public interface EInvoiceProvider {

    /** Stable code, e.g. "INDIA_IRP" / "PINT_AE". */
    String providerCode();

    /** Render the provider's payload (JSON or XML) for the given invoice data. */
    String buildPayload(EInvoiceData data);
}
