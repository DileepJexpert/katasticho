class JobWorkOrderModel {
  final String id;
  final String orderNumber;
  final String jobWorkerId;
  final String jobWorkerName;
  final String? jobWorkerGstin;
  final String orderDate;
  final String? expectedReturnDate;
  final String status;
  final String? processDescription;
  final double totalIssuedValue;
  final double totalReceivedValue;
  final String? notes;
  final List<JobWorkIssueLineModel> issueLines;
  final List<JobWorkReceiptLineModel> receiptLines;

  const JobWorkOrderModel({
    required this.id,
    required this.orderNumber,
    required this.jobWorkerId,
    required this.jobWorkerName,
    this.jobWorkerGstin,
    required this.orderDate,
    this.expectedReturnDate,
    required this.status,
    this.processDescription,
    this.totalIssuedValue = 0.0,
    this.totalReceivedValue = 0.0,
    this.notes,
    this.issueLines = const [],
    this.receiptLines = const [],
  });

  factory JobWorkOrderModel.fromJson(Map<String, dynamic> json) {
    return JobWorkOrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      jobWorkerId: json['jobWorkerId']?.toString() ?? '',
      jobWorkerName: json['jobWorkerName']?.toString() ?? 'Unknown Worker',
      jobWorkerGstin: json['jobWorkerGstin']?.toString(),
      orderDate: json['orderDate']?.toString() ?? '',
      expectedReturnDate: json['expectedReturnDate']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      processDescription: json['processDescription']?.toString(),
      totalIssuedValue: (json['totalIssuedValue'] as num?)?.toDouble() ?? 0.0,
      totalReceivedValue: (json['totalReceivedValue'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      issueLines: (json['issueLines'] as List? ?? [])
          .map((l) => JobWorkIssueLineModel.fromJson(l as Map<String, dynamic>))
          .toList(),
      receiptLines: (json['receiptLines'] as List? ?? [])
          .map((r) => JobWorkReceiptLineModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class JobWorkIssueLineModel {
  final String id;
  final String jobWorkOrderId;
  final String challanNumber;
  final String challanDate;
  final String itemId;
  final String itemName;
  final String? hsnCode;
  final String uom;
  final double issuedQuantity;
  final double returnedQuantity;
  final double pendingQuantity;
  final double unitRate;
  final double taxableValue;
  final double gstRate;
  final String? natureOfProcessing;

  const JobWorkIssueLineModel({
    required this.id,
    required this.jobWorkOrderId,
    required this.challanNumber,
    required this.challanDate,
    required this.itemId,
    required this.itemName,
    this.hsnCode,
    this.uom = 'PCS',
    this.issuedQuantity = 0.0,
    this.returnedQuantity = 0.0,
    this.pendingQuantity = 0.0,
    this.unitRate = 0.0,
    this.taxableValue = 0.0,
    this.gstRate = 0.0,
    this.natureOfProcessing,
  });

  factory JobWorkIssueLineModel.fromJson(Map<String, dynamic> json) {
    return JobWorkIssueLineModel(
      id: json['id']?.toString() ?? '',
      jobWorkOrderId: json['jobWorkOrderId']?.toString() ?? '',
      challanNumber: json['challanNumber']?.toString() ?? '',
      challanDate: json['challanDate']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? 'Item',
      hsnCode: json['hsnCode']?.toString(),
      uom: json['uom']?.toString() ?? 'PCS',
      issuedQuantity: (json['issuedQuantity'] as num?)?.toDouble() ?? 0.0,
      returnedQuantity: (json['returnedQuantity'] as num?)?.toDouble() ?? 0.0,
      pendingQuantity: (json['pendingQuantity'] as num?)?.toDouble() ?? 0.0,
      unitRate: (json['unitRate'] as num?)?.toDouble() ?? 0.0,
      taxableValue: (json['taxableValue'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0.0,
      natureOfProcessing: json['natureOfProcessing']?.toString(),
    );
  }
}

class JobWorkReceiptLineModel {
  final String id;
  final String jobWorkOrderId;
  final String inwardChallanNumber;
  final String receiptDate;
  final String finishedItemId;
  final String finishedItemName;
  final String uom;
  final double receivedQuantity;
  final String? consumedRawItemId;
  final String? consumedRawItemName;
  final double consumedQuantity;
  final double scrapQuantity;
  final double jobWorkCharges;
  final String? notes;

  const JobWorkReceiptLineModel({
    required this.id,
    required this.jobWorkOrderId,
    required this.inwardChallanNumber,
    required this.receiptDate,
    required this.finishedItemId,
    required this.finishedItemName,
    this.uom = 'PCS',
    this.receivedQuantity = 0.0,
    this.consumedRawItemId,
    this.consumedRawItemName,
    this.consumedQuantity = 0.0,
    this.scrapQuantity = 0.0,
    this.jobWorkCharges = 0.0,
    this.notes,
  });

  factory JobWorkReceiptLineModel.fromJson(Map<String, dynamic> json) {
    return JobWorkReceiptLineModel(
      id: json['id']?.toString() ?? '',
      jobWorkOrderId: json['jobWorkOrderId']?.toString() ?? '',
      inwardChallanNumber: json['inwardChallanNumber']?.toString() ?? '',
      receiptDate: json['receiptDate']?.toString() ?? '',
      finishedItemId: json['finishedItemId']?.toString() ?? '',
      finishedItemName: json['finishedItemName']?.toString() ?? 'Finished Good',
      uom: json['uom']?.toString() ?? 'PCS',
      receivedQuantity: (json['receivedQuantity'] as num?)?.toDouble() ?? 0.0,
      consumedRawItemId: json['consumedRawItemId']?.toString(),
      consumedRawItemName: json['consumedRawItemName']?.toString(),
      consumedQuantity: (json['consumedQuantity'] as num?)?.toDouble() ?? 0.0,
      scrapQuantity: (json['scrapQuantity'] as num?)?.toDouble() ?? 0.0,
      jobWorkCharges: (json['jobWorkCharges'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
    );
  }
}

class Itc04LineModel {
  final String challanNumber;
  final String challanDate;
  final String jobWorkerName;
  final String? jobWorkerGstin;
  final String itemName;
  final String? hsnCode;
  final String uom;
  final double quantity;
  final double taxableValue;
  final String? natureOfProcessing;
  final String recordType;

  const Itc04LineModel({
    required this.challanNumber,
    required this.challanDate,
    required this.jobWorkerName,
    this.jobWorkerGstin,
    required this.itemName,
    this.hsnCode,
    this.uom = 'PCS',
    this.quantity = 0.0,
    this.taxableValue = 0.0,
    this.natureOfProcessing,
    required this.recordType,
  });

  factory Itc04LineModel.fromJson(Map<String, dynamic> json) {
    return Itc04LineModel(
      challanNumber: json['challanNumber']?.toString() ?? '',
      challanDate: json['challanDate']?.toString() ?? '',
      jobWorkerName: json['jobWorkerName']?.toString() ?? 'Job Worker',
      jobWorkerGstin: json['jobWorkerGstin']?.toString(),
      itemName: json['itemName']?.toString() ?? 'Item',
      hsnCode: json['hsnCode']?.toString(),
      uom: json['uom']?.toString() ?? 'PCS',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      taxableValue: (json['taxableValue'] as num?)?.toDouble() ?? 0.0,
      natureOfProcessing: json['natureOfProcessing']?.toString(),
      recordType: json['recordType']?.toString() ?? 'SENT_INPUTS',
    );
  }
}

class Itc04SummaryModel {
  final String quarter;
  final int year;
  final int totalChallans;
  final double totalIssuedValue;
  final double totalReturnedValue;
  final double pendingValue;
  final List<Itc04LineModel> table4InputsSent;
  final List<Itc04LineModel> table5AReceivedBack;

  const Itc04SummaryModel({
    required this.quarter,
    required this.year,
    this.totalChallans = 0,
    this.totalIssuedValue = 0.0,
    this.totalReturnedValue = 0.0,
    this.pendingValue = 0.0,
    this.table4InputsSent = const [],
    this.table5AReceivedBack = const [],
  });

  factory Itc04SummaryModel.fromJson(Map<String, dynamic> json) {
    return Itc04SummaryModel(
      quarter: json['quarter']?.toString() ?? 'Q1',
      year: (json['year'] as num?)?.toInt() ?? 2026,
      totalChallans: (json['totalChallans'] as num?)?.toInt() ?? 0,
      totalIssuedValue: (json['totalIssuedValue'] as num?)?.toDouble() ?? 0.0,
      totalReturnedValue: (json['totalReturnedValue'] as num?)?.toDouble() ?? 0.0,
      pendingValue: (json['pendingValue'] as num?)?.toDouble() ?? 0.0,
      table4InputsSent: (json['table4InputsSent'] as List? ?? [])
          .map((l) => Itc04LineModel.fromJson(l as Map<String, dynamic>))
          .toList(),
      table5AReceivedBack: (json['table5AReceivedBack'] as List? ?? [])
          .map((l) => Itc04LineModel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CreateJobWorkRequest {
  final String jobWorkerId;
  final String orderDate;
  final String? expectedReturnDate;
  final String? processDescription;
  final String? notes;
  final List<Map<String, dynamic>> issueLines;

  const CreateJobWorkRequest({
    required this.jobWorkerId,
    required this.orderDate,
    this.expectedReturnDate,
    this.processDescription,
    this.notes,
    required this.issueLines,
  });

  Map<String, dynamic> toJson() => {
        'jobWorkerId': jobWorkerId,
        'orderDate': orderDate,
        if (expectedReturnDate != null) 'expectedReturnDate': expectedReturnDate,
        if (processDescription != null) 'processDescription': processDescription,
        if (notes != null) 'notes': notes,
        'issueLines': issueLines,
      };
}

class ReceiveJobWorkRequest {
  final String inwardChallanNumber;
  final String receiptDate;
  final String finishedItemId;
  final double receivedQuantity;
  final String? consumedRawItemId;
  final double consumedQuantity;
  final double scrapQuantity;
  final double jobWorkCharges;
  final String? notes;

  const ReceiveJobWorkRequest({
    required this.inwardChallanNumber,
    required this.receiptDate,
    required this.finishedItemId,
    required this.receivedQuantity,
    this.consumedRawItemId,
    this.consumedQuantity = 0.0,
    this.scrapQuantity = 0.0,
    this.jobWorkCharges = 0.0,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'inwardChallanNumber': inwardChallanNumber,
        'receiptDate': receiptDate,
        'finishedItemId': finishedItemId,
        'receivedQuantity': receivedQuantity,
        if (consumedRawItemId != null) 'consumedRawItemId': consumedRawItemId,
        'consumedQuantity': consumedQuantity,
        'scrapQuantity': scrapQuantity,
        'jobWorkCharges': jobWorkCharges,
        if (notes != null) 'notes': notes,
      };
}
