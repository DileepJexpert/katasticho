import 'package:url_launcher/url_launcher.dart';

enum Gstr2bMatchCategory {
  all,
  matched,
  valueMismatch,
  notInBooks,
  atRiskSupplierNotFiled,
}

class Gstr2bEntryModel {
  final String id;
  final String? orgId;
  final String returnPeriod;
  final String supplierGstin;
  final String? supplierName;
  final String invoiceNumber;
  final String? invoiceDate;
  final double invoiceValue;
  final double taxableValue;
  final double igst;
  final double cgst;
  final double sgst;
  final double cess;
  final String matchStatus;
  final String? matchNote;
  final String? matchedBillId;
  final String? imsAction;
  final String? imsActionBy;
  final String? imsActionAt;
  final String? imsRemarks;

  const Gstr2bEntryModel({
    required this.id,
    this.orgId,
    required this.returnPeriod,
    required this.supplierGstin,
    this.supplierName,
    required this.invoiceNumber,
    this.invoiceDate,
    required this.invoiceValue,
    required this.taxableValue,
    required this.igst,
    required this.cgst,
    required this.sgst,
    required this.cess,
    required this.matchStatus,
    this.matchNote,
    this.matchedBillId,
    this.imsAction,
    this.imsActionBy,
    this.imsActionAt,
    this.imsRemarks,
  });

  double get totalTax => igst + cgst + sgst + cess;

  factory Gstr2bEntryModel.fromJson(Map<String, dynamic> json) {
    return Gstr2bEntryModel(
      id: json['id']?.toString() ?? '',
      orgId: json['orgId']?.toString(),
      returnPeriod: json['returnPeriod']?.toString() ?? '',
      supplierGstin: json['supplierGstin']?.toString() ?? '',
      supplierName: json['supplierName']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      invoiceDate: json['invoiceDate']?.toString(),
      invoiceValue: (json['invoiceValue'] as num?)?.toDouble() ?? 0.0,
      taxableValue: (json['taxableValue'] as num?)?.toDouble() ?? 0.0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      cess: (json['cess'] as num?)?.toDouble() ?? 0.0,
      matchStatus: json['matchStatus']?.toString() ?? 'UNMATCHED',
      matchNote: json['matchNote']?.toString(),
      matchedBillId: json['matchedBillId']?.toString(),
      imsAction: json['imsAction']?.toString(),
      imsActionBy: json['imsActionBy']?.toString(),
      imsActionAt: json['imsActionAt']?.toString(),
      imsRemarks: json['imsRemarks']?.toString(),
    );
  }
}

class SupplierNotFiledModel {
  final String billId;
  final String billNumber;
  final String? vendorBillNumber;
  final String vendorName;
  final String vendorGstin;
  final String? billDate;
  final double totalAmount;
  final double itc;
  final String? phone;
  final String? email;

  const SupplierNotFiledModel({
    required this.billId,
    required this.billNumber,
    this.vendorBillNumber,
    required this.vendorName,
    required this.vendorGstin,
    this.billDate,
    required this.totalAmount,
    required this.itc,
    this.phone,
    this.email,
  });

  factory SupplierNotFiledModel.fromJson(Map<String, dynamic> json) {
    return SupplierNotFiledModel(
      billId: json['billId']?.toString() ?? '',
      billNumber: json['billNumber']?.toString() ?? '',
      vendorBillNumber: json['vendorBillNumber']?.toString(),
      vendorName: json['vendorName']?.toString() ?? 'Unknown Vendor',
      vendorGstin: json['vendorGstin']?.toString() ?? '',
      billDate: json['billDate']?.toString(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      itc: (json['itc'] as num?)?.toDouble() ?? 0.0,
      phone: (json['phone'] ?? json['mobile'])?.toString(),
      email: json['email']?.toString(),
    );
  }
}

class Gstr2bSummaryModel {
  final String period;
  final int totalEntries;
  final int matched;
  final int valueMismatch;
  final int notInBooks;
  final double matchedItc;
  final double mismatchItc;
  final double missingItc;
  final double itcAtRisk;
  final List<SupplierNotFiledModel> supplierNotFiled;

  const Gstr2bSummaryModel({
    required this.period,
    required this.totalEntries,
    required this.matched,
    required this.valueMismatch,
    required this.notInBooks,
    required this.matchedItc,
    required this.mismatchItc,
    required this.missingItc,
    required this.itcAtRisk,
    required this.supplierNotFiled,
  });

  factory Gstr2bSummaryModel.fromJson(Map<String, dynamic> json) {
    final listRaw = (json['supplierNotFiled'] as List?) ?? const [];
    final notFiledList = listRaw
        .map((e) => SupplierNotFiledModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Gstr2bSummaryModel(
      period: json['period']?.toString() ?? '',
      totalEntries: (json['totalEntries'] as num?)?.toInt() ?? 0,
      matched: (json['matched'] as num?)?.toInt() ?? 0,
      valueMismatch: (json['valueMismatch'] as num?)?.toInt() ?? 0,
      notInBooks: (json['notInBooks'] as num?)?.toInt() ?? 0,
      matchedItc: (json['matchedItc'] as num?)?.toDouble() ?? 0.0,
      mismatchItc: (json['mismatchItc'] as num?)?.toDouble() ?? 0.0,
      missingItc: (json['missingItc'] as num?)?.toDouble() ?? 0.0,
      itcAtRisk: (json['itcAtRisk'] as num?)?.toDouble() ?? 0.0,
      supplierNotFiled: notFiledList,
    );
  }
}

class VendorNudgeHelper {
  static String buildNudgeMessage({
    required String vendorName,
    required String invoiceNo,
    required String? invoiceDate,
    required double invoiceAmount,
    required double itcAmount,
    required String returnPeriod,
    String? orgName,
  }) {
    final org = (orgName != null && orgName.isNotEmpty) ? 'from $orgName ' : '';
    final dateStr = (invoiceDate != null && invoiceDate.isNotEmpty) ? ' dated $invoiceDate' : '';
    final formattedAmt = invoiceAmount.toStringAsFixed(2);
    final formattedItc = itcAmount.toStringAsFixed(2);

    return 'Dear $vendorName,\n\n'
        'This is a gentle reminder ${org}regarding Invoice #$invoiceNo$dateStr for \u20B9$formattedAmt.\n\n'
        'As per GST reconciliation for return period $returnPeriod, this invoice is currently missing in our GSTR-2B statement, putting \u20B9$formattedItc of Input Tax Credit (ITC) on hold.\n\n'
        'Kindly ensure this invoice is uploaded in your GSTR-1 / IFF filing at the earliest so that the tax credit can be claimed without disruption.\n\n'
        'Thank you for your cooperation.';
  }

  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final encodedMsg = Uri.encodeComponent(message);
    
    final uri = Uri.parse('https://wa.me/$fullPhone?text=$encodedMsg');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> launchEmail({
    required String email,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }
}
