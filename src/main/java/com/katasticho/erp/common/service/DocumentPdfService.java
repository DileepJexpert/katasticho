package com.katasticho.erp.common.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.openhtmltopdf.bidi.support.ICUBidiReorderer;
import com.openhtmltopdf.bidi.support.ICUBidiSplitter;
import com.openhtmltopdf.pdfboxout.PdfRendererBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

/**
 * HTML → PDF for all generated documents (invoices, bills, payslips, BMR,
 * food labels, …). Registers an Arabic-capable font (Noto Naskh Arabic) and
 * wires ICU-based bidi splitting + reordering so Arabic / RTL content renders
 * with correct letter shaping and direction — required for Gulf (UAE/Oman)
 * invoices. Latin content is unaffected; the document's own CSS picks the font
 * (use {@code font-family: 'Noto Naskh Arabic'} + {@code dir="rtl"} for Arabic).
 */
@Service
@Slf4j
public class DocumentPdfService {

    private static final String ARABIC_FONT_PATH = "/fonts/NotoNaskhArabic-Regular.ttf";
    /** The font-family name documents reference in CSS for Arabic/RTL text. */
    public static final String ARABIC_FONT_FAMILY = "Noto Naskh Arabic";

    public byte[] render(String html) {
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            PdfRendererBuilder builder = new PdfRendererBuilder();
            builder.useFastMode();
            // Bidi + Arabic shaping (a no-op for pure-Latin documents).
            builder.useUnicodeBidiSplitter(new ICUBidiSplitter.ICUBidiSplitterFactory());
            builder.useUnicodeBidiReorderer(new ICUBidiReorderer());
            // Register the Arabic-capable font so CSS `font-family: 'Noto Naskh
            // Arabic'` resolves. Supplied lazily per render via a fresh stream.
            builder.useFont(this::arabicFontStream, ARABIC_FONT_FAMILY);
            builder.withHtmlContent(html, null);
            builder.toStream(baos);
            builder.run();
            return baos.toByteArray();
        } catch (Exception e) {
            log.error("PDF render failed", e);
            throw new BusinessException("PDF generation failed", "PDF_ERROR");
        }
    }

    private InputStream arabicFontStream() {
        InputStream is = getClass().getResourceAsStream(ARABIC_FONT_PATH);
        if (is == null) {
            // A missing font asset must not break Latin PDFs — log and let the
            // builder fall back to its default font.
            log.warn("Arabic font not found on classpath: {}", ARABIC_FONT_PATH);
        }
        return is;
    }
}
