package com.katasticho.erp.inventory.dto;

import java.util.List;

/**
 * Result of a matrix bulk-create. {@code created} are the newly
 * persisted variants (as item summaries); {@code skipped} are the
 * combinations that already existed as live variants and were left
 * alone — the endpoint is idempotent.
 */
public record GenerateVariantsResponse(
        List<ItemResponse> created,
        List<String> skippedReasons
) {}
