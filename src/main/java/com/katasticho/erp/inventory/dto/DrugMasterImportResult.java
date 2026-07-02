package com.katasticho.erp.inventory.dto;

import java.util.List;

/**
 * Outcome of a drug-master CSV bulk import. Errors are capped at the first 50
 * so a 254k-row file with a broken column doesn't return a megabyte of noise.
 */
public record DrugMasterImportResult(
        int totalDataRows,
        int imported,
        int skippedDuplicates,
        int errorCount,
        List<String> errors,
        int saltLinked,
        int manufacturersCreated,
        boolean dryRun
) {}
