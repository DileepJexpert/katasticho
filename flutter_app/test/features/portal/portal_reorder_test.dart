import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/portal_app/data/portal_reorder_models.dart';

void main() {
  group('Portal Reorder Models Tests', () {
    test('PortalCatalogItem parses correctly with active trade schemes and stock', () {
      final json = {
        'id': 'item-101',
        'name': 'Augmentin 625 Duo Tablet',
        'sku': 'AUG625',
        'brand': 'GSK',
        'category': 'Pharma',
        'composition': 'Amoxicillin 500mg + Clavulanic Acid 125mg',
        'packSize': '10 Tablets/Strip',
        'unitOfMeasure': 'STRIP',
        'mrp': 200.0,
        'salePrice': 160.0,
        'gstRate': 5.0,
        'trackInventory': true,
        'inStock': true,
        'stockQuantity': 450.0,
        'schemeDescription': 'Buy 10 Get 1 Free',
        'schemeType': 'BUY_X_GET_Y',
        'schemeDiscountPercent': 0.0,
      };

      final item = PortalCatalogItem.fromJson(json);

      expect(item.id, 'item-101');
      expect(item.name, 'Augmentin 625 Duo Tablet');
      expect(item.brand, 'GSK');
      expect(item.composition, 'Amoxicillin 500mg + Clavulanic Acid 125mg');
      expect(item.packSize, '10 Tablets/Strip');
      expect(item.mrp, 200.0);
      expect(item.salePrice, 160.0);
      expect(item.gstRate, 5.0);
      expect(item.inStock, isTrue);
      expect(item.stockQuantity, 450.0);
      expect(item.schemeDescription, 'Buy 10 Get 1 Free');
    });

    test('PortalCartItem correctly calculates percentage scheme discount and totals', () {
      const item = PortalCatalogItem(
        id: 'item-202',
        name: 'Cetirizine 10mg',
        sku: 'CET10',
        unitOfMeasure: 'STRIP',
        mrp: 50.0,
        salePrice: 40.0,
        gstRate: 5.0,
        trackInventory: true,
        inStock: true,
        stockQuantity: 100.0,
        schemeDescription: '10% Trade Scheme',
        schemeType: 'PERCENT_DISCOUNT',
        schemeDiscountPercent: 10.0,
      );

      final cartItem = PortalCartItem(item: item, quantity: 10);

      // Effective unit rate = 40.0 - 10% = 36.0
      expect(cartItem.unitEffectiveRate, 36.0);

      // Subtotal = 36.0 * 10 = 360.0
      expect(cartItem.lineSubtotal, 360.0);

      // Tax = 360 * 5% = 18.0
      expect(cartItem.lineTax, 18.0);

      // Total = 360 + 18 = 378.0
      expect(cartItem.lineTotal, 378.0);

      // Savings compared to MRP (MRP 50 - 36) * 10 = 140.0
      expect(cartItem.mrpSavings, 140.0);
    });

    test('PortalOrderSummary parses order details and line items', () {
      final json = {
        'id': 'ord-901',
        'number': 'SO-2026-0088',
        'referenceNumber': 'PORTAL-ORD',
        'date': '2026-08-18',
        'expectedShipmentDate': '2026-08-19',
        'total': 525.0,
        'subtotal': 500.0,
        'taxAmount': 25.0,
        'status': 'CONFIRMED',
        'shippedStatus': 'NOT_SHIPPED',
        'invoicedStatus': 'NOT_INVOICED',
        'itemCount': 1,
        'notes': 'Urgent morning route delivery',
        'lines': [
          {
            'id': 'line-1',
            'itemId': 'item-101',
            'description': 'Augmentin 625 Duo Tablet',
            'quantity': 3.0,
            'quantityShipped': 0.0,
            'quantityInvoiced': 0.0,
            'unit': 'STRIP',
            'rate': 160.0,
            'discountPct': 0.0,
            'taxRate': 5.0,
            'amount': 480.0,
          }
        ]
      };

      final order = PortalOrderSummary.fromJson(json);

      expect(order.id, 'ord-901');
      expect(order.number, 'SO-2026-0088');
      expect(order.total, 525.0);
      expect(order.status, 'CONFIRMED');
      expect(order.notes, 'Urgent morning route delivery');
      expect(order.lines.length, 1);
      expect(order.lines[0].description, 'Augmentin 625 Duo Tablet');
      expect(order.lines[0].quantity, 3.0);
      expect(order.lines[0].amount, 480.0);
    });
  });
}
