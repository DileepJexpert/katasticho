package com.katasticho.erp.tax.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;
import java.util.UUID;

/**
 * Bulk PUT body for Settings → Tax Account Mapping.
 *
 * Each entry rebinds a TaxRate's input/output GL accounts. Pass {@code null}
 * for a side that should be cleared (e.g. non-recoverable tax has no input).
 */
public record UpdateTaxAccountMappingsRequest(
        @NotEmpty List<Mapping> mappings
) {
    public record Mapping(
            @NotNull UUID taxRateId,
            UUID glOutputAccountId,
            UUID glInputAccountId
    ) {}
}
