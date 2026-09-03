package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.flux.AccountFluxLine;
import com.katasticho.erp.accounting.dto.flux.FinancialFluxReportResponse;
import com.katasticho.erp.accounting.dto.report.ProfitLossResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FluxCommentaryServiceTest {

    @Mock
    private FinancialReportService financialReportService;

    @InjectMocks
    private FluxCommentaryService fluxCommentaryService;

    @Test
    void analyzeFlux_identifiesExpenseSpikesAndRevenueGrowth() {
        UUID salesAcct = UUID.randomUUID();
        UUID freightAcct = UUID.randomUUID();
        UUID officeAcct = UUID.randomUUID();

        // Base Period: Sales = 100k, Freight = 10k, Office = 5k
        ProfitLossResponse basePl = new ProfitLossResponse(
                LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31), "INR",
                new BigDecimal("100000.00"), new BigDecimal("15000.00"), new BigDecimal("85000.00"),
                List.of(new ProfitLossResponse.AccountLine(salesAcct, "4000", "Sales Revenue", new BigDecimal("100000.00"))),
                List.of(
                        new ProfitLossResponse.AccountLine(freightAcct, "5100", "Freight Outward", new BigDecimal("10000.00")),
                        new ProfitLossResponse.AccountLine(officeAcct, "5200", "Office Supplies", new BigDecimal("5000.00"))
                )
        );

        // Comp Period: Sales = 130k (+30%), Freight = 18k (+80% SPIKE), Office = 3k (-40% SAVING)
        ProfitLossResponse compPl = new ProfitLossResponse(
                LocalDate.of(2026, 8, 1), LocalDate.of(2026, 8, 31), "INR",
                new BigDecimal("130000.00"), new BigDecimal("21000.00"), new BigDecimal("109000.00"),
                List.of(new ProfitLossResponse.AccountLine(salesAcct, "4000", "Sales Revenue", new BigDecimal("130000.00"))),
                List.of(
                        new ProfitLossResponse.AccountLine(freightAcct, "5100", "Freight Outward", new BigDecimal("18000.00")),
                        new ProfitLossResponse.AccountLine(officeAcct, "5200", "Office Supplies", new BigDecimal("3000.00"))
                )
        );

        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))).thenReturn(basePl);
        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 8, 1), LocalDate.of(2026, 8, 31))).thenReturn(compPl);

        FinancialFluxReportResponse resp = fluxCommentaryService.analyzeFlux(
                "MOM",
                LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31),
                LocalDate.of(2026, 8, 1), LocalDate.of(2026, 8, 31),
                new BigDecimal("2000.00"), // minMaterialAmount = 2000
                new BigDecimal("15.00")    // minMaterialPercent = 15%
        );

        assertNotNull(resp);
        assertEquals(new BigDecimal("30000.00"), resp.getRevenueVarianceAmount());
        assertEquals(new BigDecimal("30.00"), resp.getRevenueVariancePercent());
        assertEquals(new BigDecimal("6000.00"), resp.getExpenseVarianceAmount());
        assertEquals(new BigDecimal("40.00"), resp.getExpenseVariancePercent());
        assertEquals(new BigDecimal("24000.00"), resp.getNetProfitVarianceAmount());

        // Check Freight Spiked
        AccountFluxLine freightLine = resp.getAccountLines().stream()
                .filter(l -> l.getAccountId().equals(freightAcct))
                .findFirst().orElseThrow();
        assertEquals("MATERIAL_EXPENSE_SPIKE", freightLine.getFluxDriver());
        assertTrue(freightLine.isMaterial());
        assertEquals(new BigDecimal("80.00"), freightLine.getVariancePercent());

        // Check Office Saved
        AccountFluxLine officeLine = resp.getAccountLines().stream()
                .filter(l -> l.getAccountId().equals(officeAcct))
                .findFirst().orElseThrow();
        assertEquals("MATERIAL_EXPENSE_SAVING", officeLine.getFluxDriver());
        assertTrue(officeLine.isMaterial());
        assertEquals(new BigDecimal("-40.00"), officeLine.getVariancePercent());

        // Check narrative contains mentions
        assertNotNull(resp.getExecutiveSummary());
        assertTrue(resp.getExecutiveSummary().contains("Freight Outward"));
        assertTrue(resp.getExecutiveSummary().contains("Office Supplies"));
    }
}