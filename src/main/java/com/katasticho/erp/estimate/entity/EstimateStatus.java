package com.katasticho.erp.estimate.entity;

/**
 * Estimate lifecycle states.
 *
 *   DRAFT    — freshly created, editable, deletable
 *   SENT     — emailed to customer, still editable by seller
 *   ACCEPTED — customer approved
 *   DECLINED — customer rejected
 *   INVOICED — converted to an invoice (terminal)
 *   EXPIRED  — past expiry date (informational; set lazily)
 */
public enum EstimateStatus {
    DRAFT,
    SENT,
    ACCEPTED,
    DECLINED,
    INVOICED,
    EXPIRED
}
