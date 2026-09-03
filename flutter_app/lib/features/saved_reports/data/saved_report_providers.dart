import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'saved_report_repository.dart';

final savedReportListProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(savedReportRepositoryProvider).list();
});
