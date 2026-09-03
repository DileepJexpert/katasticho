import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final kenyaRepositoryProvider = Provider<KenyaRepository>((ref) {
  return KenyaRepository(ref.watch(apiClientProvider));
});

class MpesaTransactionDto {
  final String id;
  final String orgId;
  final String mpesaReceiptNumber;
  final String transactionType;
  final String phoneNumber;
  final double amount;
  final String? partyName;
  final String? accountReference;
  final String status;
  final String? matchedInvoiceId;
  final String? matchedJournalEntryId;
  final String transactionTime;
  final String createdAt;

  const MpesaTransactionDto({
    required this.id,
    required this.orgId,
    required this.mpesaReceiptNumber,
    required this.transactionType,
    required this.phoneNumber,
    required this.amount,
    this.partyName,
    this.accountReference,
    required this.status,
    this.matchedInvoiceId,
    this.matchedJournalEntryId,
    required this.transactionTime,
    required this.createdAt,
  });

  factory MpesaTransactionDto.fromJson(Map<String, dynamic> json) {
    return MpesaTransactionDto(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      mpesaReceiptNumber: json['mpesaReceiptNumber'] as String,
      transactionType: json['transactionType'] as String? ?? 'STK_PUSH_C2B',
      phoneNumber: json['phoneNumber'] as String,
      amount: (json['amount'] as num).toDouble(),
      partyName: json['partyName'] as String?,
      accountReference: json['accountReference'] as String?,
      status: json['status'] as String? ?? 'COMPLETED',
      matchedInvoiceId: json['matchedInvoiceId'] as String?,
      matchedJournalEntryId: json['matchedJournalEntryId'] as String?,
      transactionTime: json['transactionTime'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class KenyaPayeResultDto {
  final double grossSalary;
  final double nssfTier1;
  final double nssfTier2;
  final double totalNssf;
  final double taxablePay;
  final double grossPaye;
  final double personalRelief;
  final double insuranceRelief;
  final double netPaye;
  final double shifAmount;
  final double housingLevyAmount;
  final double totalDeductions;
  final double netPay;

  const KenyaPayeResultDto({
    required this.grossSalary,
    required this.nssfTier1,
    required this.nssfTier2,
    required this.totalNssf,
    required this.taxablePay,
    required this.grossPaye,
    required this.personalRelief,
    required this.insuranceRelief,
    required this.netPaye,
    required this.shifAmount,
    required this.housingLevyAmount,
    required this.totalDeductions,
    required this.netPay,
  });

  factory KenyaPayeResultDto.fromJson(Map<String, dynamic> json) {
    return KenyaPayeResultDto(
      grossSalary: (json['grossSalary'] as num).toDouble(),
      nssfTier1: (json['nssfTier1'] as num).toDouble(),
      nssfTier2: (json['nssfTier2'] as num).toDouble(),
      totalNssf: (json['totalNssf'] as num).toDouble(),
      taxablePay: (json['taxablePay'] as num).toDouble(),
      grossPaye: (json['grossPaye'] as num).toDouble(),
      personalRelief: (json['personalRelief'] as num).toDouble(),
      insuranceRelief: (json['insuranceRelief'] as num).toDouble(),
      netPaye: (json['netPaye'] as num).toDouble(),
      shifAmount: (json['shifAmount'] as num).toDouble(),
      housingLevyAmount: (json['housingLevyAmount'] as num).toDouble(),
      totalDeductions: (json['totalDeductions'] as num).toDouble(),
      netPay: (json['netPay'] as num).toDouble(),
    );
  }
}

class KenyaRepository {
  final ApiClient _api;
  KenyaRepository(this._api);

  Future<List<MpesaTransactionDto>> listTransactions({String? status}) async {
    final res = await _api.get(
      ApiConfig.mpesaTransactions,
      queryParameters: {
        if (status != null && status != 'ALL') 'status': status,
      },
    );
    final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return list.map((e) => MpesaTransactionDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MpesaTransactionDto> initiateStkPush({
    required String phoneNumber,
    required double amount,
    String? customerName,
    String? accountReference,
    String? invoiceId,
  }) async {
    final res = await _api.post(
      ApiConfig.mpesaStkPush,
      data: {
        'phoneNumber': phoneNumber,
        'amount': amount,
        if (customerName != null) 'customerName': customerName,
        if (accountReference != null) 'accountReference': accountReference,
        if (invoiceId != null) 'invoiceId': invoiceId,
      },
    );
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return MpesaTransactionDto.fromJson(data);
  }

  Future<MpesaTransactionDto> reconcileTransaction(String transactionId, String invoiceId) async {
    final res = await _api.post(
      ApiConfig.mpesaReconcile(transactionId),
      queryParameters: {'invoiceId': invoiceId},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return MpesaTransactionDto.fromJson(data);
  }

  Future<KenyaPayeResultDto> calculatePaye({
    required double grossSalary,
    double nonCashBenefits = 0,
    double pensionContribution = 0,
  }) async {
    final res = await _api.post(
      ApiConfig.kenyaPayeCalculate,
      data: {
        'grossSalary': grossSalary,
        'nonCashBenefits': nonCashBenefits,
        'pensionContribution': pensionContribution,
      },
    );
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return KenyaPayeResultDto.fromJson(data);
  }
}