/// Typed helpers for parsing vendor credit API responses.

class VendorCreditDto {
  final Map<String, dynamic> raw;

  const VendorCreditDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get contactId => raw['contactId']?.toString() ?? '';
  String get vendorName => raw['vendorName'] as String? ?? 'Unknown';
  String get creditNumber => raw['creditNumber'] as String? ?? '--';
  String get creditDate => raw['creditDate'] as String? ?? '';
  String get purchaseBillId => raw['purchaseBillId']?.toString() ?? '';
  String get reason => raw['reason'] as String? ?? '';
  String get status => raw['status'] as String? ?? 'DRAFT';
  double get subtotal => (raw['subtotal'] as num?)?.toDouble() ?? 0;
  double get taxAmount => (raw['taxAmount'] as num?)?.toDouble() ?? 0;
  double get totalAmount => (raw['totalAmount'] as num?)?.toDouble() ?? 0;
  double get balance => (raw['balance'] as num?)?.toDouble() ?? totalAmount;
  String get currency => raw['currency'] as String? ?? 'INR';
  String get placeOfSupply => raw['placeOfSupply'] as String? ?? '';
  String? get journalEntryId => raw['journalEntryId']?.toString();
  String get createdAt => raw['createdAt'] as String? ?? '';

  List<CreditLineDto> get lines => (raw['lines'] as List? ?? [])
      .map((l) => CreditLineDto(l as Map<String, dynamic>))
      .toList();

  bool get isDraft => status == 'DRAFT';
  bool get isOpen => status == 'OPEN';
  bool get isApplied => status == 'APPLIED';
  bool get isVoid => status == 'VOID';

  /// Can apply to bills when OPEN and has remaining balance.
  bool get canApply => isOpen && balance > 0;
}

class CreditLineDto {
  final Map<String, dynamic> raw;

  const CreditLineDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  int get lineNumber => (raw['lineNumber'] as num?)?.toInt() ?? 0;
  String get description => raw['description'] as String? ?? '';
  String get hsnCode => raw['hsnCode'] as String? ?? '';
  String? get itemId => raw['itemId']?.toString();
  double get quantity => (raw['quantity'] as num?)?.toDouble() ?? 0;
  double get unitPrice => (raw['unitPrice'] as num?)?.toDouble() ?? 0;
  double get taxableAmount => (raw['taxableAmount'] as num?)?.toDouble() ?? 0;
  double get gstRate => (raw['gstRate'] as num?)?.toDouble() ?? 0;
  double get taxAmount => (raw['taxAmount'] as num?)?.toDouble() ?? 0;
  double get lineTotal => (raw['lineTotal'] as num?)?.toDouble() ?? 0;
}
