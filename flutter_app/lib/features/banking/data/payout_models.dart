class PayoutDisbursementModel {
  final String id;
  final String provider;
  final String? providerPayoutId;
  final String? utr;
  final String status;
  final String contactId;
  final String contactName;
  final double amount;
  final String currency;
  final String payoutMode;
  final String? beneficiaryName;
  final String? accountNumberMasked;
  final String? ifscCode;
  final String? vpa;
  final String? vendorPaymentId;
  final String? failureReason;
  final String? createdAt;

  const PayoutDisbursementModel({
    required this.id,
    required this.provider,
    this.providerPayoutId,
    this.utr,
    required this.status,
    required this.contactId,
    required this.contactName,
    required this.amount,
    this.currency = 'INR',
    required this.payoutMode,
    this.beneficiaryName,
    this.accountNumberMasked,
    this.ifscCode,
    this.vpa,
    this.vendorPaymentId,
    this.failureReason,
    this.createdAt,
  });

  factory PayoutDisbursementModel.fromJson(Map<String, dynamic> json) {
    return PayoutDisbursementModel(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'RAZORPAYX',
      providerPayoutId: json['providerPayoutId']?.toString(),
      utr: json['utr']?.toString(),
      status: json['status']?.toString() ?? 'INITIATED',
      contactId: json['contactId']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? 'Vendor',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      payoutMode: json['payoutMode']?.toString() ?? 'IMPS',
      beneficiaryName: json['beneficiaryName']?.toString(),
      accountNumberMasked: json['accountNumberMasked']?.toString(),
      ifscCode: json['ifscCode']?.toString(),
      vpa: json['vpa']?.toString(),
      vendorPaymentId: json['vendorPaymentId']?.toString(),
      failureReason: json['failureReason']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class PayoutDisbursementRequestPayload {
  final String contactId;
  final double amount;
  final String paidThroughAccountId;
  final String payoutMode;
  final String? beneficiaryName;
  final String? accountNumber;
  final String? ifscCode;
  final String? vpa;
  final String? narration;
  final List<BillAllocationPayload>? billAllocations;

  const PayoutDisbursementRequestPayload({
    required this.contactId,
    required this.amount,
    required this.paidThroughAccountId,
    this.payoutMode = 'IMPS',
    this.beneficiaryName,
    this.accountNumber,
    this.ifscCode,
    this.vpa,
    this.narration,
    this.billAllocations,
  });

  Map<String, dynamic> toJson() => {
        'contactId': contactId,
        'amount': amount,
        'paidThroughAccountId': paidThroughAccountId,
        'payoutMode': payoutMode,
        if (beneficiaryName != null) 'beneficiaryName': beneficiaryName,
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (ifscCode != null) 'ifscCode': ifscCode,
        if (vpa != null) 'vpa': vpa,
        if (narration != null) 'narration': narration,
        if (billAllocations != null)
          'billAllocations': billAllocations!.map((b) => b.toJson()).toList(),
      };
}

class BillAllocationPayload {
  final String billId;
  final double amountApplied;

  const BillAllocationPayload({
    required this.billId,
    required this.amountApplied,
  });

  Map<String, dynamic> toJson() => {
        'billId': billId,
        'amountApplied': amountApplied,
      };
}
