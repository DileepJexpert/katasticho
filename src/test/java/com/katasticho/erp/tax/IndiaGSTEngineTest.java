package com.katasticho.erp.tax;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

class IndiaGSTEngineTest {

    private IndiaGSTEngine engine;

    @BeforeEach
    void setUp() {
        engine = new IndiaGSTEngine();
    }

    @Test
    void shouldCalculateCgstSgstForIntraState() {
        // Same state: Maharashtra -> Maharashtra
        var item = new TaxEngine.TaxableItem("Widget", "8471", new BigDecimal("10000"), new BigDecimal("18"));
        var context = new TaxEngine.TaxContext("IN", "MH", "IN", "MH", "8471",
                TaxEngine.TransactionType.DOMESTIC, LocalDate.now(), false);

        TaxEngine.TaxResult result = engine.calculateTax(item, context);

        assertEquals(2, result.components().size());
        assertEquals("CGST", result.components().get(0).componentCode());
        assertEquals("SGST", result.components().get(1).componentCode());
        assertEquals(new BigDecimal("9.00"), result.components().get(0).rate());
        assertEquals(new BigDecimal("900.00"), result.components().get(0).amount());
        assertEquals(new BigDecimal("900.00"), result.components().get(1).amount());
        assertEquals(new BigDecimal("1800.00"), result.totalTaxAmount());
    }

    @Test
    void shouldCalculateIgstForInterState() {
        // Different state: Maharashtra -> Karnataka
        var item = new TaxEngine.TaxableItem("Widget", "8471", new BigDecimal("10000"), new BigDecimal("18"));
        var context = new TaxEngine.TaxContext("IN", "MH", "IN", "KA", "8471",
                TaxEngine.TransactionType.DOMESTIC, LocalDate.now(), false);

        TaxEngine.TaxResult result = engine.calculateTax(item, context);

        assertEquals(1, result.components().size());
        assertEquals("IGST", result.components().get(0).componentCode());
        assertEquals(0, new BigDecimal("18").compareTo(result.components().get(0).rate()));
        assertEquals(new BigDecimal("1800.00"), result.components().get(0).amount());
        assertEquals(new BigDecimal("1800.00"), result.totalTaxAmount());
    }

    @Test
    void shouldReturnZeroForZeroRate() {
        var item = new TaxEngine.TaxableItem("Exempt Item", "0000", new BigDecimal("5000"), BigDecimal.ZERO);
        var context = new TaxEngine.TaxContext("IN", "MH", "IN", "MH", "0000",
                TaxEngine.TransactionType.DOMESTIC, LocalDate.now(), false);

        TaxEngine.TaxResult result = engine.calculateTax(item, context);

        assertTrue(result.components().isEmpty());
        assertEquals(BigDecimal.ZERO, result.totalTaxAmount());
    }

    @Test
    void shouldHandle5PercentGST() {
        var item = new TaxEngine.TaxableItem("Food Item", "1001", new BigDecimal("1000"), new BigDecimal("5"));
        var context = new TaxEngine.TaxContext("IN", "MH", "IN", "MH", "1001",
                TaxEngine.TransactionType.DOMESTIC, LocalDate.now(), false);

        TaxEngine.TaxResult result = engine.calculateTax(item, context);

        assertEquals(2, result.components().size());
        assertEquals(new BigDecimal("2.50"), result.components().get(0).rate());
        assertEquals(new BigDecimal("25.00"), result.components().get(0).amount());
        assertEquals(new BigDecimal("50.00"), result.totalTaxAmount());
    }

    @Test
    void shouldReturnCorrectRegimeCode() {
        assertEquals("INDIA_GST", engine.getTaxRegimeCode());
        assertEquals("GST", engine.getTaxLabel());
        assertEquals("GSTIN", engine.getTaxIdLabel());
    }
}
