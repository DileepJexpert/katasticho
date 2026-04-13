package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;
import java.util.Map;

/**
 * Bulk-create payload for {@code POST /api/v1/item-groups/{id}/generate-variants}.
 *
 * <p>Each entry in {@link #combinations} is one row from the matrix
 * grid the operator just ticked, e.g. {@code {"size":"M","color":"Red"}}.
 * The service:
 * <ol>
 *   <li>Validates every key/value against the group's
 *       {@code attribute_definitions}.</li>
 *   <li>Mints a child SKU as {@code <skuPrefix>-<value1>-<value2>-...}
 *       (or rejects with {@code GROUP_NO_SKU_PREFIX} if the group has none).</li>
 *   <li>Skips combinations that already exist as live variants — the
 *       endpoint is idempotent so the operator can re-run it safely.</li>
 *   <li>Inherits HSN, GST, UoM, and default prices from the group
 *       into each new item via the same one-shot inheritance path
 *       used by single-variant create.</li>
 * </ol>
 */
public record GenerateVariantsRequest(
        @NotEmpty(message = "At least one combination is required")
        List<Map<String, String>> combinations
) {}
