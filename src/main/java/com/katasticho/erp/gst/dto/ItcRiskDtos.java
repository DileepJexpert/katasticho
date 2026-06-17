package com.katasticho.erp.gst.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * ITC-at-risk monitor DTOs — the preventive, pre-cutoff view of input tax credit
 * that a late-filing supplier would block.
 */
public class ItcRiskDtos {

    /** One supplier whose unfiled GSTR-1 puts the buyer's ITC at risk. */
    public record SupplierRisk(
            UUID contactId,
            String supplierName,
            String gstin,
            String phone,
            BigDecimal itcAtRisk,        // ₹ of input credit blocked until they file
            int invoiceCount,
            List<String> invoiceNumbers,
            String draftMessage,         // ready-to-forward nudge to the supplier
            String whatsappUrl           // wa.me deep link pre-filled with draftMessage
    ) {}

    /**
     * @param dataAvailable false when we have no filing signal yet (no GSTR-2A/2B
     *        fetched or uploaded) — the monitor stays silent rather than flagging
     *        every supplier and crying wolf.
     */
    public record ItcRiskReport(
            String period,
            boolean dataAvailable,
            BigDecimal totalItcAtRisk,
            int suppliersAtRisk,
            List<SupplierRisk> suppliers,
            String message,
            String source,              // GSTR_2A | GSTR_2B | UPLOAD — provenance of the filing data
            java.time.Instant lastRefreshedAt,  // when that data was last pulled (null if never)
            int daysToDeadline,         // days until the GSTR-1 filing cutoff (11th); negative if passed
            String urgency              // OVERDUE | CRITICAL | URGENT | NORMAL
    ) {}

    private ItcRiskDtos() {}
}
