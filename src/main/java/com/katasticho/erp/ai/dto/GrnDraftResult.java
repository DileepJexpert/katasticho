package com.katasticho.erp.ai.dto;

import java.util.List;
import java.util.UUID;

/**
 * Outcome of drafting (or approving) an AI-drafted goods receipt.
 *
 * <p>{@code suggestionId} is the AI Inbox entry, {@code grnId} is the DRAFT
 * (or, after approval, RECEIVED) stock receipt. {@code unmatchedCount} counts
 * scan lines the matcher couldn't bind to a PO line — the operator should
 * eyeball those before approving (they post against whatever the AI scanned
 * but carry no PO FK). {@code warnings} surfaces things the human should
 * glance at before approving.
 */
public record GrnDraftResult(
        UUID suggestionId,
        UUID grnId,
        String grnNumber,
        String status,
        UUID supplierId,
        String supplierName,
        UUID purchaseOrderId,
        String purchaseOrderNumber,
        int lineCount,
        int unmatchedCount,
        double confidence,
        List<String> warnings
) {}
