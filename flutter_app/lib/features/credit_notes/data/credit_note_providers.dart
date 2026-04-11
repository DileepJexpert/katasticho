import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'credit_note_repository.dart';

/// Fetches credit notes list (paginated).
final creditNoteListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(creditNoteRepositoryProvider);
  return repo.listCreditNotes();
});

/// Fetches a single credit note by ID.
final creditNoteDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(creditNoteRepositoryProvider);
    return repo.getCreditNote(id);
  },
);
