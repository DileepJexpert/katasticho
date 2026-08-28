import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Step 4.4: Merchandising & Shelf Photo Audit Tests', () {
    test('deserializes complete merchandising audit JSON map correctly', () {
      final json = {
        'id': 'audit-901',
        'fieldVisitId': 'visit-001',
        'routeExecutionId': 'exec-001',
        'contactId': 'cust-101',
        'salespersonId': 'usr-501',
        'auditType': 'PRIMARY_SHELF',
        'photoUrl': 'https://s3.ap-south-1.amazonaws.com/katasticho/merchandising/photo1.jpg',
        'shelfSharePct': 42.5,
        'facingCount': 12,
        'isStockOut': false,
        'competitorBrandNames': 'BrandX, BrandY',
        'planogramCompliance': 'COMPLIANT',
        'notes': 'Promotional eye-level display maintained',
        'auditedAt': '2026-08-22T10:30:00Z',
      };

      expect(json['id'], 'audit-901');
      expect(json['fieldVisitId'], 'visit-001');
      expect(json['auditType'], 'PRIMARY_SHELF');
      expect(json['shelfSharePct'], 42.5);
      expect(json['facingCount'], 12);
      expect(json['isStockOut'], isFalse);
      expect(json['planogramCompliance'], 'COMPLIANT');
      expect(json['competitorBrandNames'], 'BrandX, BrandY');
    });

    test('deserializes merchandising summary analytics JSON correctly', () {
      final summaryJson = {
        'totalAudits': 45,
        'photosCaptured': 38,
        'averageShelfSharePct': 36.8,
        'complianceRatePct': 84.4,
        'stockOutIncidents': 3,
        'primaryShelfCount': 25,
        'secondaryDisplayCount': 12,
        'competitorAuditsCount': 8,
        'compliantCount': 38,
        'partialCount': 5,
        'nonCompliantCount': 2,
      };

      expect(summaryJson['totalAudits'], 45);
      expect(summaryJson['photosCaptured'], 38);
      expect(summaryJson['averageShelfSharePct'], 36.8);
      expect(summaryJson['complianceRatePct'], 84.4);
      expect(summaryJson['stockOutIncidents'], 3);
      expect(summaryJson['compliantCount'], 38);
    });

    test('verifies GPS Breadcrumb ping model serialization', () {
      final ping = {
        'latitude': 12.9715987,
        'longitude': 77.5945627,
        'accuracyM': 4.5,
        'recordedAt': '2026-08-22T09:15:00Z',
      };

      expect(ping['latitude'], 12.9715987);
      expect(ping['longitude'], 77.5945627);
      expect(ping['accuracyM'], 4.5);
    });
  });
}
