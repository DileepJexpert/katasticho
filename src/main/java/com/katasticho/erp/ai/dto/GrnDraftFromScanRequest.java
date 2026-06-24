package com.katasticho.erp.ai.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Reviewed scan payload that the AI drafting layer turns into a DRAFT
 * {@code stock_receipt} (GRN) plus an AI Inbox suggestion. Photo-to-GRN
 * mirror of {@link BillDraftFromScanRequest}.
 *
 * <p>When {@code purchaseOrderId} is set, each scan line is fuzzy-matched
 * by description against the PO's lines and the resolved {@code itemId} +
 * {@code purchaseOrderLineId} are stamped end-to-end so the P2P FK loop
 * (PO → GRN → Bill) sees them. When no PO is supplied, the GRN is drafted
 * stand-alone against the caller-supplied warehouse.
 */
public record GrnDraftFromScanRequest(
        /** Optional source PO — when present every line attempts a name match
         *  against the PO's lines. */
        UUID purchaseOrderId,
        /** Required when {@code purchaseOrderId} is null; defaults to the PO's
         *  warehouse when present. */
        UUID warehouseId,
        /** Informational only — vendor for a stand-alone GRN is resolved via
         *  the PO's supplier. */
        String supplierName,
        /** Caller-supplied supplier id when there's no PO. Stand-alone GRNs
         *  must be raised against a known supplier — there's no GRN-only
         *  vendor creation path, intentionally. */
        UUID supplierId,
        /** The supplier's bill / challan number off the photo (becomes
         *  {@code stock_receipt.supplier_invoice_no}). */
        String vendorBillNumber,
        LocalDate vendorBillDate,
        LocalDate receiptDate,
        String notes,
        /** Extraction confidence 0..1; carried through to the suggestion. */
        Double confidence,
        @NotEmpty(message = "At least one line is required")
        @Valid
        List<ScanLine> lines
) {
    public record ScanLine(
            String description,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal mrp,
            String batchNumber,
            LocalDate expiryDate,
            /** GST % from the photo — informational; GRN itself doesn't post
             *  accounting. */
            BigDecimal gstRate
    ) {}
}
