import 'dart:convert';

class SavedReportDto {
  final String id;
  final String name;
  final String description;
  final String baseReportKey;
  final List<String> columnKeys;
  final Map<String, dynamic> filters;
  final List<String> tags;
  final bool isPublic;
  final String createdBy;
  final String createdAt;

  SavedReportDto(Map<String, dynamic> m)
      : id = m['id']?.toString() ?? '',
        name = m['name']?.toString() ?? '',
        description = m['description']?.toString() ?? '',
        baseReportKey = m['baseReportKey']?.toString() ?? '',
        columnKeys = _parseStringList(m['columnKeys']),
        filters = _parseMap(m['filters']),
        tags = _parseStringList(m['tags']),
        isPublic = m['public'] == true || m['isPublic'] == true,
        createdBy = m['createdBy']?.toString() ?? '',
        createdAt = m['createdAt']?.toString() ?? '';

  static List<String> _parseStringList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static Map<String, dynamic> _parseMap(dynamic v) {
    if (v == null) return {};
    if (v is Map<String, dynamic>) return v;
    if (v is String) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return {};
  }
}

class ReportScheduleDto {
  final String id;
  final String savedReportId;
  final String frequency;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final String sendTime;
  final List<String> recipientEmails;
  final String subjectTemplate;
  final bool active;
  final String? lastSentAt;
  final String? nextRunAt;

  ReportScheduleDto(Map<String, dynamic> m)
      : id = m['id']?.toString() ?? '',
        savedReportId = m['savedReportId']?.toString() ?? '',
        frequency = m['frequency']?.toString() ?? 'DAILY',
        dayOfWeek = m['dayOfWeek'] as int?,
        dayOfMonth = m['dayOfMonth'] as int?,
        sendTime = m['sendTime']?.toString() ?? '08:00',
        recipientEmails = SavedReportDto._parseStringList(m['recipientEmails']),
        subjectTemplate = m['subjectTemplate']?.toString() ?? '',
        active = m['active'] == true,
        lastSentAt = m['lastSentAt']?.toString(),
        nextRunAt = m['nextRunAt']?.toString();

  String get frequencyLabel {
    switch (frequency) {
      case 'DAILY':
        return 'Every day';
      case 'WEEKLY':
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return 'Weekly on ${dayOfWeek != null && dayOfWeek! >= 1 && dayOfWeek! <= 7 ? days[dayOfWeek! - 1] : '?'}';
      case 'MONTHLY':
        return 'Monthly on day ${dayOfMonth ?? '?'}';
      default:
        return frequency;
    }
  }
}

// Known base reports the builder supports
class BaseReportOption {
  final String key;
  final String label;
  final String group;
  final bool hasDateRange;
  final List<String> availableColumns;

  const BaseReportOption({
    required this.key,
    required this.label,
    required this.group,
    this.hasDateRange = true,
    required this.availableColumns,
  });

  static const List<BaseReportOption> all = [
    BaseReportOption(
      key: 'sales-register',
      label: 'Sales Register',
      group: 'Sales',
      availableColumns: ['invoiceNumber', 'invoiceDate', 'customerName', 'totalAmount', 'taxAmount', 'netAmount', 'paymentStatus'],
    ),
    BaseReportOption(
      key: 'purchase-register',
      label: 'Purchase Register',
      group: 'Purchases',
      availableColumns: ['billNumber', 'billDate', 'vendorName', 'totalAmount', 'taxAmount', 'netAmount', 'paymentStatus'],
    ),
    BaseReportOption(
      key: 'stock-summary',
      label: 'Stock Summary',
      group: 'Inventory',
      hasDateRange: false,
      availableColumns: ['itemName', 'hsn', 'unit', 'openingQty', 'receivedQty', 'issuedQty', 'closingQty', 'closingValue'],
    ),
    BaseReportOption(
      key: 'stock-movement',
      label: 'Stock Movement',
      group: 'Inventory',
      availableColumns: ['date', 'itemName', 'movementType', 'qty', 'unit', 'reference'],
    ),
    BaseReportOption(
      key: 'low-stock',
      label: 'Low Stock Alert',
      group: 'Inventory',
      hasDateRange: false,
      availableColumns: ['itemName', 'unit', 'currentQty', 'reorderLevel', 'deficit', 'estimatedCost'],
    ),
    BaseReportOption(
      key: 'day-book',
      label: 'Day Book',
      group: 'Financial',
      availableColumns: ['date', 'journalNumber', 'description', 'debit', 'credit', 'module'],
    ),
    BaseReportOption(
      key: 'cash-flow',
      label: 'Cash Flow Statement',
      group: 'Financial',
      availableColumns: ['date', 'salesInflow', 'arCollections', 'cogsOutflow', 'apPayments', 'netFlow'],
    ),
    BaseReportOption(
      key: 'gst-summary',
      label: 'GST Summary',
      group: 'Tax',
      availableColumns: ['month', 'outputTax', 'inputCredit', 'netPayable', 'cgst', 'sgst', 'igst'],
    ),
    BaseReportOption(
      key: 'pending-dispatch',
      label: 'Pending Dispatch',
      group: 'Sales',
      hasDateRange: false,
      availableColumns: ['soNumber', 'soDate', 'customerName', 'itemName', 'orderedQty', 'dispatchedQty', 'pendingQty'],
    ),
  ];
}
