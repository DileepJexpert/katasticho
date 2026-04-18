import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A named filter snapshot the user can recall later.
class SavedView {
  final String id;
  final String name;
  final String entityType; // e.g. 'invoices', 'bills', 'contacts'
  final Map<String, String?> filters; // filter key → value

  const SavedView({
    required this.id,
    required this.name,
    required this.entityType,
    required this.filters,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entityType': entityType,
        'filters': filters,
      };

  factory SavedView.fromJson(Map<String, dynamic> json) => SavedView(
        id: json['id'] as String,
        name: json['name'] as String,
        entityType: json['entityType'] as String,
        filters: Map<String, String?>.from(json['filters'] as Map),
      );
}

const _kPrefsKey = 'katasticho_saved_views_v1';

class SavedViewsNotifier extends StateNotifier<List<SavedView>> {
  SavedViewsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SavedView.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPrefsKey, jsonEncode(state.map((v) => v.toJson()).toList()));
  }

  Future<void> save(SavedView view) async {
    state = [
      ...state.where((v) => v.id != view.id),
      view,
    ];
    await _persist();
  }

  Future<void> delete(String id) async {
    state = state.where((v) => v.id != id).toList();
    await _persist();
  }

  List<SavedView> forEntity(String entityType) =>
      state.where((v) => v.entityType == entityType).toList();
}

final savedViewsProvider =
    StateNotifierProvider<SavedViewsNotifier, List<SavedView>>(
  (ref) => SavedViewsNotifier(),
);
