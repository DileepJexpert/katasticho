import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'packaging_barcode_models.dart';

final packagingBarcodeRepositoryProvider =
    Provider<PackagingBarcodeRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return PackagingBarcodeRepository(client);
});

final itemPackagingBarcodesProvider = FutureProvider.autoDispose
    .family<List<PackagingBarcodeModel>, String>((ref, itemId) async {
  final repo = ref.watch(packagingBarcodeRepositoryProvider);
  return repo.fetchPackagingBarcodes(itemId);
});

class PackagingBarcodeRepository {
  final ApiClient _client;

  PackagingBarcodeRepository(this._client);

  Future<List<PackagingBarcodeModel>> fetchPackagingBarcodes(String itemId) async {
    final response = await _client.get(ApiConfig.itemPackagingBarcodes(itemId));
    final data = response.data['data'] as List? ?? [];
    return data
        .map((b) => PackagingBarcodeModel.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<PackagingBarcodeModel> addPackagingBarcode(
      String itemId, CreatePackagingBarcodeRequest req) async {
    final response = await _client.post(
      ApiConfig.itemPackagingBarcodes(itemId),
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return PackagingBarcodeModel.fromJson(data);
  }

  Future<PackagingBarcodeModel> updatePackagingBarcode(
      String id, CreatePackagingBarcodeRequest req) async {
    final response = await _client.put(
      ApiConfig.itemPackagingBarcode(id),
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return PackagingBarcodeModel.fromJson(data);
  }

  Future<void> deletePackagingBarcode(String id) async {
    await _client.delete(ApiConfig.itemPackagingBarcode(id));
  }

  Future<ResolvedBarcodeModel> resolveBarcode(String barcode) async {
    final response =
        await _client.get(ApiConfig.resolvePackagingBarcode(barcode));
    final data = response.data['data'] as Map<String, dynamic>;
    return ResolvedBarcodeModel.fromJson(data);
  }
}
