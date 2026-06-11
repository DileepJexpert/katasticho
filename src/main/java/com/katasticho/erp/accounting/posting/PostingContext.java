package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.manufacturing.entity.WorkOrder;

public record PostingContext(String sourceType, Object source) {

    public static final String SALES_INVOICE = "SALES_INVOICE";
    public static final String MANUFACTURING_WIP = "MANUFACTURING_WIP";
    public static final String MANUFACTURING_COMPLETION = "MANUFACTURING_COMPLETION";

    public static PostingContext salesInvoice(Invoice invoice) {
        return new PostingContext(SALES_INVOICE, invoice);
    }

    public static PostingContext manufacturingWip(WorkOrder workOrder) {
        return new PostingContext(MANUFACTURING_WIP, workOrder);
    }

    public static PostingContext manufacturingCompletion(WorkOrder workOrder) {
        return new PostingContext(MANUFACTURING_COMPLETION, workOrder);
    }

    public Invoice requireSalesInvoice() {
        if (!SALES_INVOICE.equals(sourceType) || !(source instanceof Invoice invoice)) {
            throw new IllegalArgumentException("Posting context does not contain a sales invoice");
        }
        return invoice;
    }

    public WorkOrder requireWorkOrder() {
        if (!(source instanceof WorkOrder wo)) {
            throw new IllegalArgumentException("Posting context does not contain a work order");
        }
        return wo;
    }
}
