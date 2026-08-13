package com.katasticho.erp.contact.dto;

/**
 * Tenant-scoped role counts for the unified contact master.
 *
 * <p>Customer and vendor counts are role counts and therefore include BOTH
 * contacts. Supplier is deliberately separate: it counts contacts that have
 * an active procurement supplier projection.</p>
 */
public record ContactSummaryResponse(
        long total,
        long customers,
        long vendors,
        long suppliers
) {}
