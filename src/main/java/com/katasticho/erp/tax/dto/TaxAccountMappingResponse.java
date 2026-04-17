package com.katasticho.erp.tax.dto;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * One row in Settings → Taxes & Compliance → Tax Account Mapping.
 *
 * Each {@link com.katasticho.erp.tax.entity.TaxRate} surfaces its currently
 * bound input/output GL accounts so the user can re-point them to a different
 * CoA row. {@code customized} is TRUE once the row has been edited from the
 * UI — startup re-seed never clobbers customized rows.
 */
public record TaxAccountMappingResponse(
        UUID taxRateId,
        String name,
        String rateCode,
        BigDecimal percentage,
        String taxType,
        UUID glOutputAccountId,
        String glOutputAccountCode,
        String glOutputAccountName,
        UUID glInputAccountId,
        String glInputAccountCode,
        String glInputAccountName,
        boolean recoverable,
        boolean customized
) {}
