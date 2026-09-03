import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final barcodeLabelRepositoryProvider = Provider<BarcodeLabelRepository>((ref) {
  return BarcodeLabelRepository(ref.watch(apiClientProvider));
});

class BarcodeLabelGenerateRequestDto {
  final String itemName;
  final String? sku;
  final String barcodeValue;
  final String barcodeType; // CODE128, EAN13, QR
  final String? batchNumber;
  final String? expiryDate;
  final double? mrp;
  final double? sellingPrice;
  final String? fssaiLicNo;
  final String? companyName;
  final int labelWidthMm;
  final int labelHeightMm;
  final int dpi;
  final int copies;

  const BarcodeLabelGenerateRequestDto({
    required this.itemName,
    this.sku,
    required this.barcodeValue,
    this.barcodeType = 'CODE128',
    this.batchNumber,
    this.expiryDate,
    this.mrp,
    this.sellingPrice,
    this.fssaiLicNo,
    this.companyName,
    this.labelWidthMm = 50,
    this.labelHeightMm = 25,
    this.dpi = 203,
    this.copies = 1,
  });

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        if (sku != null && sku!.isNotEmpty) 'sku': sku,
        'barcodeValue': barcodeValue,
        'barcodeType': barcodeType,
        if (batchNumber != null && batchNumber!.isNotEmpty) 'batchNumber': batchNumber,
        if (expiryDate != null && expiryDate!.isNotEmpty) 'expiryDate': expiryDate,
        if (mrp != null) 'mrp': mrp,
        if (sellingPrice != null) 'sellingPrice': sellingPrice,
        if (fssaiLicNo != null && fssaiLicNo!.isNotEmpty) 'fssaiLicNo': fssaiLicNo,
        if (companyName != null && companyName!.isNotEmpty) 'companyName': companyName,
        'labelWidthMm': labelWidthMm,
        'labelHeightMm': labelHeightMm,
        'dpi': dpi,
        'copies': copies,
      };
}

class BarcodeLabelGenerateResponseDto {
  final String zplCode;
  final String eplCode;
  final int labelWidthDots;
  final int labelHeightDots;
  final int copies;

  const BarcodeLabelGenerateResponseDto({
    required this.zplCode,
    required this.eplCode,
    required this.labelWidthDots,
    required this.labelHeightDots,
    required this.copies,
  });

  factory BarcodeLabelGenerateResponseDto.fromJson(Map<String, dynamic> json) {
    return BarcodeLabelGenerateResponseDto(
      zplCode: json['zplCode'] as String? ?? '',
      eplCode: json['eplCode'] as String? ?? '',
      labelWidthDots: json['labelWidthDots'] as int? ?? 400,
      labelHeightDots: json['labelHeightDots'] as int? ?? 200,
      copies: json['copies'] as int? ?? 1,
    );
  }
}

class BarcodeLabelRepository {
  final ApiClient _api;
  BarcodeLabelRepository(this._api);

  Future<BarcodeLabelGenerateResponseDto> generateLabel(BarcodeLabelGenerateRequestDto req) async {
    final res = await _api.post(ApiConfig.barcodeLabelGenerate, data: req.toJson());
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return BarcodeLabelGenerateResponseDto.fromJson(data);
  }
}