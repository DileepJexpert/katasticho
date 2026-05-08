package com.katasticho.erp.ai.dto;

import java.time.LocalDate;

public record AiAgentRunResponse(
        LocalDate from,
        LocalDate to,
        int scannedInvoices,
        int scannedInvoiceLines,
        int scannedStockMovements,
        int createdSuggestions,
        int skippedDuplicates
) {}
