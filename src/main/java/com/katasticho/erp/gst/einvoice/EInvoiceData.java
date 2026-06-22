package com.katasticho.erp.gst.einvoice;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Provider-neutral e-invoice payload. A country-specific {@link EInvoiceProvider}
 * (India IRN/INV-01 JSON, UAE PINT-AE UBL XML, …) renders this into its own
 * schema. Keeping the mapping (real {@code Invoice} → this) separate from the
 * schema generation lets us add a country's e-invoice format without touching
 * the invoice domain.
 */
public record EInvoiceData(
        String invoiceNumber,
        LocalDate issueDate,
        String currencyCode,
        Party supplier,
        Party customer,
        List<Line> lines,
        BigDecimal taxableTotal,
        BigDecimal taxTotal,
        BigDecimal grandTotal,
        BigDecimal vatRatePercent) {

    /** A trading party (seller or buyer) — name + tax-registration number. */
    public record Party(String name, String taxId, String countryCode) {}

    /** One invoice line. */
    public record Line(
            String description,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal lineNet,
            BigDecimal vatRatePercent) {}
}
