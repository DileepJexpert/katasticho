package com.katasticho.erp.ai.dto;

import java.math.BigDecimal;
import java.util.List;

public record BillScanResponse(
        String vendorName,
        String vendorGstin,
        String invoiceNumber,
        String invoiceDate,
        String dueDate,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal totalAmount,
        String currency,
        List<LineItem> lineItems,
        TaxDetails taxDetails,
        double confidence
) {
    public record LineItem(
            int lineNumber,
            String description,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal amount,
            BigDecimal gstRate
    ) {}

    public record TaxDetails(
            BigDecimal cgst,
            BigDecimal sgst,
            BigDecimal igst,
            String taxRegime
    ) {}
}
