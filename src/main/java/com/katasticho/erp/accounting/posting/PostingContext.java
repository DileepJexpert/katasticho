package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.ar.entity.Invoice;

public record PostingContext(String sourceType, Object source) {

    public static final String SALES_INVOICE = "SALES_INVOICE";

    public static PostingContext salesInvoice(Invoice invoice) {
        return new PostingContext(SALES_INVOICE, invoice);
    }

    public Invoice requireSalesInvoice() {
        if (!SALES_INVOICE.equals(sourceType) || !(source instanceof Invoice invoice)) {
            throw new IllegalArgumentException("Posting context does not contain a sales invoice");
        }
        return invoice;
    }
}
