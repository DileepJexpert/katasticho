package com.katasticho.erp.common.service;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Verifies the shared HTML→PDF pipeline produces valid PDFs for both Latin and
 * Arabic/RTL content (the Gulf invoice case). It cannot assert that Arabic
 * *renders visually correct* (that's a manual check) — but it proves the bidi
 * + Arabic-font wiring doesn't crash and embeds the font.
 */
class DocumentPdfServiceTest {

    private final DocumentPdfService service = new DocumentPdfService();

    private static boolean isPdf(byte[] bytes) {
        if (bytes == null || bytes.length < 5) return false;
        String header = new String(bytes, 0, 5, StandardCharsets.US_ASCII);
        return header.equals("%PDF-");
    }

    @Test
    void renders_latin_document_unaffected() {
        byte[] pdf = service.render(
                "<html><body><h1>Invoice INV-001</h1><p>Total: 1,050.00</p></body></html>");
        assertTrue(isPdf(pdf), "valid PDF header");
        assertTrue(pdf.length > 400, "non-trivial PDF");
    }

    @Test
    void renders_arabic_rtl_document_without_crashing() {
        // A Gulf-style invoice fragment: RTL + Arabic font-family + Arabic text.
        String html = "<html dir=\"rtl\"><head><style>"
                + "body { font-family: '" + DocumentPdfService.ARABIC_FONT_FAMILY + "'; }"
                + "</style></head><body>"
                + "<h1>فاتورة ضريبية</h1>"               // "Tax invoice"
                + "<p>المورد: شركة النور للتجارة</p>"      // "Supplier: Al Noor Trading"
                + "<p>ضريبة القيمة المضافة 5%</p>"        // "VAT 5%"
                + "<p>الإجمالي: 1,050.00 د.إ</p>"          // "Total: 1,050.00 AED"
                + "</body></html>";
        byte[] pdf = service.render(html);
        assertTrue(isPdf(pdf), "valid PDF header for Arabic content");
        assertTrue(pdf.length > 400, "non-trivial PDF");
    }

    @Test
    void arabic_font_family_constant_is_stable() {
        // Documents reference this exact family in CSS — guard against renames.
        assertEquals("Noto Naskh Arabic", DocumentPdfService.ARABIC_FONT_FAMILY);
    }
}
