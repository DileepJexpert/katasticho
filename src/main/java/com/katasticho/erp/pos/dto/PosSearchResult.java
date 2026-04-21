package com.katasticho.erp.pos.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Lightweight item result optimized for POS counter search speed.
 */
public record PosSearchResult(
        UUID id,
        String name,
        String sku,
        String barcode,
        BigDecimal rate,
        UUID taxGroupId,
        String taxGroupName,
        String hsnCode,
        String unit,
        BigDecimal currentStock,
        boolean weightBasedBilling,
        UUID batchId,
        LocalDate batchExpiryDate
) {}
