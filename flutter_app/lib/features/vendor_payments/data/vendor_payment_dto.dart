/// Typed helpers for parsing vendor payment API responses.

class VendorPaymentDto {
  final Map<String, dynamic> raw;

  const VendorPaymentDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get contactId => raw['contactId']?.toString() ?? '';
  String get vendorName => raw['vendorName'] as String? ?? 'Unknown';
  String get paymentNumber => raw['paymentNumber'] as String? ?? '--';
  String get paymentDate => raw['paymentDate'] as String? ?? '';
  double get amount => (raw['amount'] as num?)?.toDouble() ?? 0;
  String get currency => raw['currency'] as String? ?? 'INR';
  String get paymentMode => raw['paymentMode'] as String? ?? '--';
  String get paidThroughId => raw['paidThroughId']?.toString() ?? '';
  String get referenceNumber => raw['referenceNumber'] as String? ?? '';
  double get tdsAmount => (raw['tdsAmount'] as num?)?.toDouble() ?? 0;
  String get notes => raw['notes'] as String? ?? '';
  String? get journalEntryId => raw['journalEntryId']?.toString();
  String get createdAt => raw['createdAt'] as String? ?? '';

  List<PaymentAllocationDto> get allocations =>
      (raw['allocations'] as List? ?? [])
          .map((a) => PaymentAllocationDto(a as Map<String, dynamic>))
          .toList();

  /// Human-readable payment mode.
  String get paymentModeLabel => paymentMode.replaceAll('_', ' ');
}

class PaymentAllocationDto {
  final Map<String, dynamic> raw;

  const PaymentAllocationDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get billId => raw['billId']?.toString() ?? '';
  String get billNumber => raw['billNumber'] as String? ?? '--';
  double get amountApplied =>
      (raw['amountApplied'] as num?)?.toDouble() ?? 0;
}
