package com.katasticho.erp.accounting.forex.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** DTOs for the period-end forex revaluation feature. */
public final class ForexRevaluationDtos {

    private ForexRevaluationDtos() {}

    /** One revalued open document (AR invoice or AP bill). */
    public record RevaluationLine(
            String side,             // AR | AP
            UUID documentId,
            String documentNumber,
            String currency,
            BigDecimal balanceDue,   // in document currency
            BigDecimal bookRate,     // rate the document was posted at (foreign -> base)
            BigDecimal closingRate,  // rate as of the revaluation date
            BigDecimal bookBase,     // balanceDue * bookRate
            BigDecimal closingBase,  // balanceDue * closingRate
            BigDecimal delta) {}     // closingBase - bookBase (base currency)

    /** The full computed picture — used for preview and as the run payload. */
    public record RevaluationResult(
            LocalDate asOfDate,
            String baseCurrency,
            BigDecimal arDelta,
            BigDecimal apDelta,
            BigDecimal netGainLoss,  // arDelta - apDelta (gain when positive)
            int revaluedDocumentCount,
            List<RevaluationLine> lines,
            List<String> warnings) {}

    public record RevaluationRunResponse(
            UUID id,
            LocalDate asOfDate,
            String baseCurrency,
            BigDecimal arDelta,
            BigDecimal apDelta,
            BigDecimal netGainLoss,
            int revaluedDocumentCount,
            UUID revalJournalEntryId,
            UUID reversalJournalEntryId) {}
}
