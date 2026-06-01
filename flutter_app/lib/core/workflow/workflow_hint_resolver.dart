enum WorkflowHintVariant { info, workflow, warning, success }

class WorkflowHint {
  final String title;
  final String body;
  final WorkflowHintVariant variant;

  const WorkflowHint({
    required this.title,
    required this.body,
    this.variant = WorkflowHintVariant.workflow,
  });
}

class WorkflowHintResolver {
  const WorkflowHintResolver._();

  static WorkflowHint? resolve({
    required String pageKey,
    String? status,
    String? businessType,
    String? industryCode,
  }) {
    final type = (businessType ?? '').toUpperCase();
    final industry = (industryCode ?? '').toUpperCase();
    final isPharma = type.contains('PHARMA') || industry.contains('PHARMA');
    final isDistributor = type.contains('DISTRIBUTOR');
    final isManufacturer = type.contains('MANUFACTUR');
    final isRetailer = type.contains('RETAIL');

    return switch (pageKey) {
      'purchase_order.detail' => _purchaseOrderDetail(
          isPharma: isPharma,
          isDistributor: isDistributor,
          isManufacturer: isManufacturer,
          isRetailer: isRetailer,
        ),
      'stock_receipt.create' => _stockReceiptCreate(isPharma: isPharma),
      'stock_receipt.detail' => _stockReceiptDetail(status),
      'sales_order.detail' => _salesOrderDetail(
          isPharma: isPharma,
          isDistributor: isDistributor,
          isManufacturer: isManufacturer,
          isRetailer: isRetailer,
        ),
      'delivery_challan.create' => _deliveryChallanCreate(),
      'delivery_challan.detail' => _deliveryChallanDetail(status),
      _ => null,
    };
  }

  static WorkflowHint _purchaseOrderDetail({
    required bool isPharma,
    required bool isDistributor,
    required bool isManufacturer,
    required bool isRetailer,
  }) {
    if (isPharma && isDistributor) {
      return const WorkflowHint(
        title: 'Purchase commitment',
        body:
            'Order medicines from supplier or company. Verify batch, expiry, rack, and cost in Goods Receipt before stock increases.',
      );
    }
    if (isManufacturer) {
      return const WorkflowHint(
        title: 'Purchase commitment',
        body:
            'Order raw materials or bought-out goods. Inventory increases only after Goods Receipt is posted.',
      );
    }
    if (isRetailer) {
      return const WorkflowHint(
        title: 'Purchase commitment',
        body:
            'Order goods from supplier. Create Goods Receipt when goods physically arrive.',
      );
    }
    return const WorkflowHint(
      title: 'Purchase commitment',
      body:
          'Purchase Order records supplier commitment. Stock increases only after Goods Receipt is received.',
    );
  }

  static WorkflowHint _stockReceiptCreate({required bool isPharma}) {
    return WorkflowHint(
      title: 'Verify before posting',
      body: isPharma
          ? 'Enter actual received quantity, batch, expiry, rack, and purchase cost. Stock changes only after Receive Stock on the receipt detail page.'
          : 'Enter actual received quantity and purchase cost. Stock changes only after Receive Stock on the receipt detail page.',
    );
  }

  static WorkflowHint _stockReceiptDetail(String? status) {
    if ((status ?? '').toUpperCase() == 'DRAFT') {
      return const WorkflowHint(
        title: 'Ready to receive',
        body:
            'Receive Stock posts inventory movement and batch records. Use it only after quantity, batch, expiry, rack, and cost are checked.',
        variant: WorkflowHintVariant.warning,
      );
    }
    return const WorkflowHint(
      title: 'Receipt posted',
      body:
          'This Goods Receipt has already updated inventory. Corrections should use reversal or adjustment flows, not direct edits.',
      variant: WorkflowHintVariant.success,
    );
  }

  static WorkflowHint _salesOrderDetail({
    required bool isPharma,
    required bool isDistributor,
    required bool isManufacturer,
    required bool isRetailer,
  }) {
    if (isPharma && isDistributor) {
      return const WorkflowHint(
        title: 'Customer demand',
        body:
            'Record chemist or dealer demand here. Stock decreases only after Delivery Challan dispatch.',
      );
    }
    if (isDistributor) {
      return const WorkflowHint(
        title: 'Customer demand',
        body:
            'Record retailer order booking here. Dispatch happens through Delivery Challan.',
      );
    }
    if (isManufacturer) {
      return const WorkflowHint(
        title: 'Customer demand',
        body:
            'Record buyer demand here. Production and dispatch planning starts from confirmed orders.',
      );
    }
    if (isRetailer) {
      return const WorkflowHint(
        title: 'Customer demand',
        body:
            'Use Sales Order for advance or delivery orders. Use POS for counter sales.',
      );
    }
    return const WorkflowHint(
      title: 'Customer demand',
      body:
          'Sales Order records customer demand. Stock moves only when a Delivery Challan is dispatched.',
    );
  }

  static WorkflowHint _deliveryChallanCreate() {
    return const WorkflowHint(
      title: 'Prepare dispatch',
      body:
          'Confirm shipped quantities and transport details. Stock moves only after Dispatch on the challan detail page.',
    );
  }

  static WorkflowHint _deliveryChallanDetail(String? status) {
    final normalized = (status ?? '').toUpperCase();
    if (normalized == 'DRAFT') {
      return const WorkflowHint(
        title: 'Dispatch checkpoint',
        body:
            'Dispatch deducts inventory and updates the linked Sales Order as shipped or partially shipped.',
        variant: WorkflowHintVariant.warning,
      );
    }
    if (normalized == 'DISPATCHED' || normalized == 'DELIVERED') {
      return const WorkflowHint(
        title: 'Ready for billing',
        body:
            'Stock movement is complete. Create Sales Invoice from this challan to post receivable and accounting.',
        variant: WorkflowHintVariant.success,
      );
    }
    return const WorkflowHint(
      title: 'Dispatch document',
      body:
          'Delivery Challan prepares stock movement against a Sales Order; invoice posting is a separate billing step.',
    );
  }
}
