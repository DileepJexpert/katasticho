import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final singleEntryVoucherRepositoryProvider = Provider<SingleEntryVoucherRepository>((ref) {
  return SingleEntryVoucherRepository(ref.watch(apiClientProvider));
});

class SingleEntryVoucherLineDto {
  final String accountId;
  final double amount;
  final String? narration;
  final String? costCenterId;

  SingleEntryVoucherLineDto({
    required this.accountId,
    required this.amount,
    this.narration,
    this.costCenterId,
  });

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'amount': amount,
        if (narration != null && narration!.isNotEmpty) 'narration': narration,
        if (costCenterId != null) 'costCenterId': costCenterId,
      };
}

class SingleEntryVoucherRepository {
  final ApiClient _api;
  SingleEntryVoucherRepository(this._api);

  Future<Map<String, dynamic>> postVoucher({
    required String voucherType, // PAYMENT, RECEIPT, CONTRA
    required String primaryAccountId,
    required String date,
    String? referenceNumber,
    String? narration,
    String status = 'POSTED',
    required List<SingleEntryVoucherLineDto> lines,
  }) async {
    final res = await _api.post(ApiConfig.singleEntryVouchers, data: {
      'voucherType': voucherType,
      'primaryAccountId': primaryAccountId,
      'date': date,
      if (referenceNumber != null && referenceNumber.isNotEmpty)
        'referenceNumber': referenceNumber,
      if (narration != null && narration.isNotEmpty) 'narration': narration,
      'status': status,
      'lines': lines.map((l) => l.toJson()).toList(),
    });
    return res.data as Map<String, dynamic>;
  }
}