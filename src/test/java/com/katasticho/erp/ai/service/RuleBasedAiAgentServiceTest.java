package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.repository.InvoiceLineRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RuleBasedAiAgentServiceTest {

    private final InvoiceRepository invoiceRepository = mock(InvoiceRepository.class);
    private final InvoiceLineRepository invoiceLineRepository = mock(InvoiceLineRepository.class);
    private final StockMovementRepository stockMovementRepository = mock(StockMovementRepository.class);
    private final AiSuggestionRepository aiSuggestionRepository = mock(AiSuggestionRepository.class);
    private final AiTelemetryService aiTelemetryService = mock(AiTelemetryService.class);

    private final RuleBasedAiAgentService service = new RuleBasedAiAgentService(
            invoiceRepository,
            invoiceLineRepository,
            stockMovementRepository,
            aiSuggestionRepository,
            aiTelemetryService
    );

    @Test
    void scanPostedInvoiceCreatesMissingHsnSuggestion() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID lineId = UUID.randomUUID();
        Invoice invoice = Invoice.builder()
                .id(invoiceId)
                .orgId(orgId)
                .invoiceNumber("INV-1")
                .invoiceDate(LocalDate.of(2026, 5, 13))
                .status("SENT")
                .totalAmount(new BigDecimal("1180.00"))
                .build();
        InvoiceLine line = InvoiceLine.builder()
                .id(lineId)
                .invoice(invoice)
                .lineNumber(1)
                .description("Taxable service")
                .hsnCode("")
                .taxableAmount(new BigDecimal("1000.00"))
                .gstRate(new BigDecimal("18.00"))
                .taxAmount(new BigDecimal("180.00"))
                .lineTotal(new BigDecimal("1180.00"))
                .build();

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)).thenReturn(Optional.of(invoice));
        when(invoiceLineRepository.findByInvoiceIdOrderByLineNumber(invoiceId)).thenReturn(List.of(line));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), eq("INVOICE"), eq(invoiceId), eq(lineId), eq("MISSING_HSN"), any(Collection.class)))
                .thenReturn(false);

        int created = service.scanPostedInvoice(orgId, invoiceId);

        assertThat(created).isEqualTo(1);
        ArgumentCaptor<AiSuggestion> captor = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(captor.capture());
        assertThat(captor.getValue().getSuggestionType()).isEqualTo("MISSING_HSN");
        assertThat(captor.getValue().getSuggestedAction()).isEqualTo("REVIEW_HSN");
        verify(aiTelemetryService).recordModelRun(
                eq(orgId),
                eq("INVOICE_REVIEW"),
                eq("deterministic_rules"),
                eq("1"),
                eq("internal"),
                any(),
                any(),
                eq(BigDecimal.ONE),
                any()
        );
    }

    @Test
    void scanPostedInvoiceSkipsDraftInvoices() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = Invoice.builder()
                .id(invoiceId)
                .orgId(orgId)
                .invoiceNumber("INV-1")
                .invoiceDate(LocalDate.of(2026, 5, 13))
                .status("DRAFT")
                .totalAmount(BigDecimal.ZERO)
                .build();

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)).thenReturn(Optional.of(invoice));

        int created = service.scanPostedInvoice(orgId, invoiceId);

        assertThat(created).isZero();
        verify(invoiceLineRepository, never()).findByInvoiceIdOrderByLineNumber(invoiceId);
        verify(aiSuggestionRepository, never()).save(any(AiSuggestion.class));
    }
}
