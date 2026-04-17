package com.katasticho.erp.accounting.defaults.dto;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;
import java.util.UUID;

/**
 * Bulk PUT body for Settings → Accounting → Default Accounts.
 *
 * Each entry rebinds {@code purpose} to {@code accountId}. Purposes
 * not included in {@code mappings} are left unchanged.
 */
public record UpdateDefaultAccountsRequest(
        @NotEmpty List<Mapping> mappings
) {
    public record Mapping(
            @NotNull DefaultAccountPurpose purpose,
            @NotNull UUID accountId
    ) {}
}
