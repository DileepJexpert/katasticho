import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final pdfTemplateRepositoryProvider = Provider<PdfTemplateRepository>((ref) {
  return PdfTemplateRepository(ref.watch(apiClientProvider));
});

class PdfTemplateSettingDto {
  final String? id;
  final String documentType;
  final String templateTheme;
  final String primaryColor;
  final String headerLayout;
  final bool showGstColumns;
  final bool showHsnColumn;
  final bool showPaymentQr;
  final bool showTerms;
  final String? termsAndConditions;
  final bool showSignature;
  final String? signatureLabel;
  final String? watermarkText;
  final bool active;

  const PdfTemplateSettingDto({
    this.id,
    required this.documentType,
    this.templateTheme = 'CLASSIC',
    this.primaryColor = '#0F8576',
    this.headerLayout = 'LOGO_LEFT',
    this.showGstColumns = true,
    this.showHsnColumn = true,
    this.showPaymentQr = true,
    this.showTerms = true,
    this.termsAndConditions,
    this.showSignature = true,
    this.signatureLabel = 'Authorized Signatory',
    this.watermarkText,
    this.active = true,
  });

  factory PdfTemplateSettingDto.fromJson(Map<String, dynamic> json) {
    return PdfTemplateSettingDto(
      id: json['id'] as String?,
      documentType: json['documentType'] as String? ?? 'INVOICE',
      templateTheme: json['templateTheme'] as String? ?? 'CLASSIC',
      primaryColor: json['primaryColor'] as String? ?? '#0F8576',
      headerLayout: json['headerLayout'] as String? ?? 'LOGO_LEFT',
      showGstColumns: json['showGstColumns'] as bool? ?? true,
      showHsnColumn: json['showHsnColumn'] as bool? ?? true,
      showPaymentQr: json['showPaymentQr'] as bool? ?? true,
      showTerms: json['showTerms'] as bool? ?? true,
      termsAndConditions: json['termsAndConditions'] as String?,
      showSignature: json['showSignature'] as bool? ?? true,
      signatureLabel: json['signatureLabel'] as String? ?? 'Authorized Signatory',
      watermarkText: json['watermarkText'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'documentType': documentType,
        'templateTheme': templateTheme,
        'primaryColor': primaryColor,
        'headerLayout': headerLayout,
        'showGstColumns': showGstColumns,
        'showHsnColumn': showHsnColumn,
        'showPaymentQr': showPaymentQr,
        'showTerms': showTerms,
        'termsAndConditions': termsAndConditions,
        'showSignature': showSignature,
        'signatureLabel': signatureLabel,
        'watermarkText': watermarkText,
        'active': active,
      };
}

class PdfTemplateRepository {
  final ApiClient _api;
  PdfTemplateRepository(this._api);

  Future<PdfTemplateSettingDto> getSetting(String docType) async {
    final res = await _api.get(ApiConfig.pdfTemplateSettingByDocType(docType));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return PdfTemplateSettingDto.fromJson(data);
  }

  Future<PdfTemplateSettingDto> saveSetting(PdfTemplateSettingDto dto) async {
    final res = await _api.post(ApiConfig.pdfTemplateSettings, data: dto.toJson());
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return PdfTemplateSettingDto.fromJson(data);
  }
}