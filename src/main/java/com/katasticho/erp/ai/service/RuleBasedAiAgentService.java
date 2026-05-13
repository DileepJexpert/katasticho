package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.AiAgentRunResponse;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.repository.InvoiceLineRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class RuleBasedAiAgentService {

    private static final BigDecimal HIGH_VALUE_INVOICE_THRESHOLD = new BigDecimal("100000.00");
    private static final BigDecimal GST_TOLERANCE = new BigDecimal("1.00");
    private static final BigDecimal LARGE_STOCK_COST_THRESHOLD = new BigDecimal("5000.00");
    private static final BigDecimal LARGE_STOCK_QTY_THRESHOLD = new BigDecimal("100.00");
    private static final Set<String> OPEN_STATUSES = Set.of("PENDING", "DEFERRED");

    private final InvoiceRepository invoiceRepository;
    private final InvoiceLineRepository invoiceLineRepository;
    private final StockMovementRepository stockMovementRepository;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final AiTelemetryService aiTelemetryService;
    private final AiModelRegistryService aiModelRegistryService;

    @Transactional
    public AiAgentRunResponse runRuleChecks(Integer days) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }

        int lookbackDays = days == null ? 30 : Math.max(1, Math.min(days, 365));
        LocalDate to = LocalDate.now();
        LocalDate from = to.minusDays(lookbackDays - 1L);

        List<Invoice> invoices = invoiceRepository.findPostedByOrgAndDateRange(orgId, from, to);
        List<InvoiceLine> lines = invoiceLineRepository.findPostedLinesByOrgAndDateRange(
                orgId, from, to, PageRequest.of(0, 1000));
        List<StockMovement> movements = stockMovementRepository
                .findByOrgIdAndMovementDateBetweenOrderByMovementDateDescCreatedAtDesc(orgId, from, to);

        Counter counter = new Counter();
        long started = System.nanoTime();
        try {
            scanHighValueInvoices(orgId, invoices, counter);
            scanInvoiceLineTaxIssues(orgId, lines, counter);
            scanStockMovementIssues(orgId, movements, counter);
        } finally {
            recordRuleRun(
                    orgId,
                    "BATCH_RULE_REVIEW",
                    Map.of(
                            "from", from.toString(),
                            "to", to.toString(),
                            "invoiceCount", invoices.size(),
                            "lineCount", lines.size(),
                            "movementCount", movements.size()
                    ),
                    counter,
                    started
            );
        }

        return new AiAgentRunResponse(
                from,
                to,
                invoices.size(),
                lines.size(),
                movements.size(),
                counter.created,
                counter.skippedDuplicates
        );
    }

    @Transactional
    public int scanPostedInvoice(UUID orgId, UUID invoiceId) {
        long started = System.nanoTime();
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> new BusinessException(
                        "Invoice not found",
                        "INVOICE_NOT_FOUND"
                ));

        if ("DRAFT".equals(invoice.getStatus()) || "CANCELLED".equals(invoice.getStatus())) {
            return 0;
        }

        List<InvoiceLine> lines = invoiceLineRepository.findByInvoiceIdOrderByLineNumber(invoiceId);
        Counter counter = new Counter();
        try {
            scanHighValueInvoices(orgId, List.of(invoice), counter);
            scanInvoiceLineTaxIssues(orgId, lines, counter);
        } finally {
            recordRuleRun(
                    orgId,
                    "INVOICE_REVIEW",
                    Map.of(
                            "entityType", "INVOICE",
                            "entityId", invoiceId.toString(),
                            "invoiceNumber", invoice.getInvoiceNumber(),
                            "lineCount", lines.size()
                    ),
                    counter,
                    started
            );
        }
        return counter.created;
    }

    private void scanHighValueInvoices(UUID orgId, List<Invoice> invoices, Counter counter) {
        for (Invoice invoice : invoices) {
            if (invoice.getTotalAmount() == null ||
                    invoice.getTotalAmount().compareTo(HIGH_VALUE_INVOICE_THRESHOLD) < 0) {
                continue;
            }
            createIfNew(
                    orgId,
                    "INVOICE",
                    invoice.getId(),
                    null,
                    "HIGH_VALUE_INVOICE",
                    "REVIEW_INVOICE",
                    "High-value posted invoice should be reviewed before close or GST filing.",
                    "HIGH",
                    new BigDecimal("85.000"),
                    new BigDecimal("0.820"),
                    Map.of(
                            "invoiceNumber", invoice.getInvoiceNumber(),
                            "invoiceDate", invoice.getInvoiceDate().toString(),
                            "totalAmount", invoice.getTotalAmount(),
                            "threshold", HIGH_VALUE_INVOICE_THRESHOLD
                    ),
                    counter
            );
        }
    }

    private void scanInvoiceLineTaxIssues(UUID orgId, List<InvoiceLine> lines, Counter counter) {
        for (InvoiceLine line : lines) {
            Invoice invoice = line.getInvoice();
            if (invoice == null) {
                continue;
            }
            boolean hasTaxableValue = positive(line.getTaxableAmount());
            boolean missingHsn = hasTaxableValue &&
                    (line.getHsnCode() == null || line.getHsnCode().isBlank());
            if (missingHsn) {
                createIfNew(
                        orgId,
                        "INVOICE",
                        invoice.getId(),
                        line.getId(),
                        "MISSING_HSN",
                        "REVIEW_HSN",
                        "Invoice line has taxable value but no HSN/SAC code.",
                        "MEDIUM",
                        new BigDecimal("70.000"),
                        new BigDecimal("0.900"),
                        Map.of(
                                "invoiceNumber", invoice.getInvoiceNumber(),
                                "lineNumber", line.getLineNumber(),
                                "description", line.getDescription(),
                                "taxableAmount", line.getTaxableAmount()
                        ),
                        counter
                );
            }

            if (hasTaxableValue && line.getGstRate() != null && line.getTaxAmount() != null) {
                BigDecimal expectedTax = line.getTaxableAmount()
                        .multiply(line.getGstRate())
                        .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
                BigDecimal diff = expectedTax.subtract(line.getTaxAmount()).abs();
                if (diff.compareTo(GST_TOLERANCE) > 0) {
                    createIfNew(
                            orgId,
                            "INVOICE",
                            invoice.getId(),
                            line.getId(),
                            "GST_AMOUNT_MISMATCH",
                            "REVIEW_TAX_CALCULATION",
                            "Invoice line GST amount differs from taxable amount multiplied by GST rate.",
                            "HIGH",
                            new BigDecimal("80.000"),
                            new BigDecimal("0.880"),
                            Map.of(
                                    "invoiceNumber", invoice.getInvoiceNumber(),
                                    "lineNumber", line.getLineNumber(),
                                    "description", line.getDescription(),
                                    "taxableAmount", line.getTaxableAmount(),
                                    "gstRate", line.getGstRate(),
                                    "actualTaxAmount", line.getTaxAmount(),
                                    "expectedTaxAmount", expectedTax,
                                    "difference", diff
                            ),
                            counter
                    );
                }
            }
        }
    }

    private void scanStockMovementIssues(UUID orgId, List<StockMovement> movements, Counter counter) {
        for (StockMovement movement : movements) {
            if (movement.isReversal() || movement.isReversed()) {
                continue;
            }
            boolean largeNegativeAdjustment = movement.getMovementType() == MovementType.ADJUSTMENT
                    && movement.getQuantity() != null
                    && movement.getQuantity().signum() < 0
                    && (movement.getQuantity().abs().compareTo(LARGE_STOCK_QTY_THRESHOLD) >= 0
                    || abs(movement.getTotalCost()).compareTo(LARGE_STOCK_COST_THRESHOLD) >= 0);

            if (!largeNegativeAdjustment) {
                continue;
            }

            createIfNew(
                    orgId,
                    "STOCK_MOVEMENT",
                    movement.getId(),
                    null,
                    "LARGE_STOCK_ADJUSTMENT",
                    "REVIEW_STOCK_ADJUSTMENT",
                    "Large negative stock adjustment should be reviewed for shrinkage, expiry, or data entry error.",
                    "HIGH",
                    new BigDecimal("82.000"),
                    new BigDecimal("0.840"),
                    Map.of(
                            "movementDate", movement.getMovementDate().toString(),
                            "movementType", movement.getMovementType().name(),
                            "itemId", movement.getItemId().toString(),
                            "warehouseId", movement.getWarehouseId().toString(),
                            "quantity", movement.getQuantity(),
                            "totalCost", movement.getTotalCost(),
                            "referenceType", movement.getReferenceType() != null ? movement.getReferenceType().name() : "",
                            "referenceNumber", movement.getReferenceNumber() != null ? movement.getReferenceNumber() : ""
                    ),
                    counter
            );
        }
    }

    private void createIfNew(UUID orgId,
                             String entityType,
                             UUID entityId,
                             UUID entityLineId,
                             String suggestionType,
                             String suggestedAction,
                             String reasoning,
                             String priority,
                             BigDecimal priorityScore,
                             BigDecimal confidence,
                             Map<String, Object> suggestedValue,
                             Counter counter) {
        boolean exists = aiSuggestionRepository.existsOpenSuggestion(
                orgId, entityType, entityId, entityLineId, suggestionType, OPEN_STATUSES);
        if (exists) {
            counter.skippedDuplicates++;
            return;
        }

        aiSuggestionRepository.save(AiSuggestion.builder()
                .orgId(orgId)
                .entityType(entityType)
                .entityId(entityId)
                .entityLineId(entityLineId)
                .suggestionType(suggestionType)
                .suggestedAction(suggestedAction)
                .suggestedValue(suggestedValue)
                .reasoning(reasoning)
                .confidence(confidence)
                .agentName("rule_based_foundation")
                .modelName("deterministic_rules")
                .modelVersion("1")
                .promptVersion("none")
                .priority(priority)
                .priorityScore(priorityScore)
                .status("PENDING")
                .build());
        counter.created++;
        counter.confidenceTotal = counter.confidenceTotal.add(confidence == null ? BigDecimal.ZERO : confidence);
    }

    private boolean positive(BigDecimal value) {
        return value != null && value.signum() > 0;
    }

    private BigDecimal abs(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value.abs();
    }

    private int elapsedMs(long startedNanos) {
        return Math.toIntExact((System.nanoTime() - startedNanos) / 1_000_000);
    }

    private void recordRuleRun(UUID orgId,
                               String taskType,
                               Map<String, Object> input,
                               Counter counter,
                               long startedNanos) {
        try {
            ActiveAiModel model = aiModelRegistryService.getActiveModel(taskType);
            aiTelemetryService.recordModelRun(
                    orgId,
                    taskType,
                    model.modelName(),
                    model.modelVersion(),
                    model.provider(),
                    input,
                    Map.of(
                            "suggestionsCreated", counter.created,
                            "duplicatesSkipped", counter.skippedDuplicates
                    ),
                    averageConfidence(counter),
                    elapsedMs(startedNanos)
            );
        } catch (Exception e) {
            log.warn("AI telemetry failed for task {} org {}: {}", taskType, orgId, e.getMessage());
        }
    }

    private BigDecimal averageConfidence(Counter counter) {
        if (counter.created <= 0 || counter.confidenceTotal.compareTo(BigDecimal.ZERO) == 0) {
            return BigDecimal.ONE;
        }
        return counter.confidenceTotal.divide(new BigDecimal(counter.created), 3, RoundingMode.HALF_UP);
    }

    private static class Counter {
        private int created;
        private int skippedDuplicates;
        private BigDecimal confidenceTotal = BigDecimal.ZERO;
    }
}
