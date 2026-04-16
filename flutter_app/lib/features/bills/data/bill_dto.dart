/// Typed helpers for parsing bill API responses.
///
/// The API returns `Map<String, dynamic>` — these helpers provide safe
/// accessors so screens don't need to repeat null-coalescing everywhere.

class BillDto {
  final Map<String, dynamic> raw;

  const BillDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get billNumber => raw['billNumber'] as String? ?? '--';
  String get vendorBillNumber => raw['vendorBillNumber'] as String? ?? '';
  String get vendorName => raw['vendorName'] as String? ?? 'Unknown';
  String get contactId => raw['contactId']?.toString() ?? '';
  String get status => raw['status'] as String? ?? 'DRAFT';
  String get billDate => raw['billDate'] as String? ?? '';
  String get dueDate => raw['dueDate'] as String? ?? '';
  String get placeOfSupply => raw['placeOfSupply'] as String? ?? '';
  bool get reverseCharge => raw['reverseCharge'] == true;
  String get notes => raw['notes'] as String? ?? '';
  String get currency => raw['currency'] as String? ?? 'INR';

  double get subtotal => (raw['subtotal'] as num?)?.toDouble() ?? 0;
  double get taxAmount => (raw['taxAmount'] as num?)?.toDouble() ?? 0;
  double get totalAmount => (raw['totalAmount'] as num?)?.toDouble() ?? 0;
  double get amountPaid => (raw['amountPaid'] as num?)?.toDouble() ?? 0;
  double get balanceDue =>
      (raw['balanceDue'] as num?)?.toDouble() ?? totalAmount;

  String? get journalEntryId => raw['journalEntryId']?.toString();

  List<BillLineDto> get lines => (raw['lines'] as List? ?? [])
      .map((l) => BillLineDto(l as Map<String, dynamic>))
      .toList();

  bool get isDraft => status == 'DRAFT';
  bool get isOpen => status == 'OPEN';
  bool get isOverdue => status == 'OVERDUE';
  bool get isPartiallyPaid => status == 'PARTIALLY_PAID';
  bool get isPaid => status == 'PAID';
  bool get isVoid => status == 'VOID';
  bool get isPayable => isOpen || isPartiallyPaid || isOverdue;
}

class BillLineDto {
  final Map<String, dynamic> raw;

  const BillLineDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String? get itemId => raw['itemId']?.toString();
  String get itemName => raw['itemName'] as String? ?? 'Item';
  String get description => raw['description'] as String? ?? '';
  double get quantity => (raw['quantity'] as num?)?.toDouble() ?? 0;
  double get unitPrice => (raw['unitPrice'] as num?)?.toDouble() ?? 0;
  double get lineTotal => (raw['lineTotal'] as num?)?.toDouble() ?? 0;
  double get taxAmount => (raw['taxAmount'] as num?)?.toDouble() ?? 0;
  String? get taxGroupName => raw['taxGroupName'] as String?;
  String get accountCode => raw['accountCode'] as String? ?? '';
}

class BillPaymentDto {
  final Map<String, dynamic> raw;

  const BillPaymentDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get paymentNumber => raw['paymentNumber'] as String? ?? '--';
  String get paymentMethod => raw['paymentMethod'] as String? ?? '--';
  String get paymentDate => raw['paymentDate'] as String? ?? '';
  double get amount => (raw['amount'] as num?)?.toDouble() ?? 0;
  String get status => raw['status'] as String? ?? '';
}
