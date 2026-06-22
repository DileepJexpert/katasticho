import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Shared font setup for the `pdf`-package preview screens (invoice, bill,
/// delivery challan, estimate).
///
/// Problem: a bare `pw.Document()` defaults to the built-in Helvetica, which is
/// Latin-only — an Arabic customer name or item (UAE/Oman orgs) renders as empty
/// boxes (tofu). Fix: build a [pw.ThemeData] whose base/bold faces stay Helvetica
/// (so Latin output is byte-identical to before for Indian orgs) but with
/// **Noto Naskh Arabic registered as a font fallback**, so any Arabic glyph the
/// base font can't draw falls through to the Arabic face.
///
/// The TTF is bundled at `assets/fonts/NotoNaskhArabic-Regular.ttf` (the same
/// face the backend `DocumentPdfService` uses for its 10 server-side doc types,
/// so server and client PDFs render Arabic identically). Loaded + parsed once
/// and cached for the session.
class PdfFonts {
  PdfFonts._();

  static pw.Font? _arabic;
  static pw.ThemeData? _theme;

  /// The bundled Noto Naskh Arabic face, loaded + cached on first use.
  static Future<pw.Font> arabic() async {
    final cached = _arabic;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
    final font = pw.Font.ttf(data);
    _arabic = font;
    return font;
  }

  /// A document theme that keeps Helvetica for Latin text and falls back to the
  /// Arabic face for glyphs Helvetica can't render. Pass to `pw.Document(theme:)`.
  /// Cached after the first build.
  static Future<pw.ThemeData> theme() async {
    final cached = _theme;
    if (cached != null) return cached;
    final ar = await arabic();
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
      // Arabic has no distinct bold/italic face here; the regular face is the
      // fallback for every weight — acceptable for names/items on a doc.
      fontFallback: [ar],
    );
    _theme = theme;
    return theme;
  }
}
