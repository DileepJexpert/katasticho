package com.katasticho.erp.ai.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Structured payload extracted from a goods-receipt-style photo (typically the
 * supplier's invoice or challan the truck arrived with). Mirrors
 * {@link BillScanResponse} but is shaped around what a GRN cares about — batch
 * numbers, expiry dates and the received-qty / unit-cost pair that drive
 * inventory posting — instead of the tax block that drives a vendor bill.
 */
public record GrnScanResponse(
        String supplierName,
        String supplierGstin,
        String invoiceNumber,
        String invoiceDate,
        BigDecimal subtotal,
        BigDecimal totalAmount,
        String currency,
        List<ScanLine> lines,
        double confidence
) {
    public record ScanLine(
            int lineNumber,
            String description,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal mrp,
            String batchNumber,
            /** YYYY-MM-DD; the prompt converts MM/YY expiry codes to the last
             *  day of the month. */
            String expiryDate,
            BigDecimal gstRate
    ) {}
}
