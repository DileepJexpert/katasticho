import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:katasticho/core/widgets/k_typeahead_field.dart';

Future<List<String>> _alwaysFruit(String q) async {
  // "Always fruit" — a deterministic stub for the WIDGET tests (debounce, overlay
  // render, keyboard nav). It returns the full list for any non-empty query so the
  // assertions don't depend on which letters happen to appear in each fruit.
  const all = ['Apple', 'Banana', 'Cherry'];
  if (q.isEmpty) return const [];
  return all;
}

Widget _harness({
  Future<List<String>> Function(String)? onSearch,
  ValueChanged<String>? onSelected,
  ValueChanged<String>? onCreateNew,
  int debounceMs = 100,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: KTypeaheadField<String>(
          label: 'Item',
          onSearch: onSearch ?? _alwaysFruit,
          displayString: (v) => v,
          itemBuilder: (v) => KTypeaheadItem(title: v),
          onSelected: onSelected ?? (_) {},
          onCreateNew: onCreateNew,
          debounceMs: debounceMs,
          minChars: 1,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('typing → debounce → results render in overlay',
      (tester) async {
    await tester.pumpWidget(_harness());
    final field = find.byType(TextFormField);
    await tester.tap(field);
    await tester.pump();

    await tester.enterText(field, 'a');
    // Run past the debounce + microtask for the Future to settle.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Cherry'), findsOneWidget);
  });

  testWidgets('↓ then Enter commits the highlighted row', (tester) async {
    String? picked;
    await tester.pumpWidget(_harness(onSelected: (v) => picked = v));

    final field = find.byType(TextFormField);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'a');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    // Highlight starts at index 0 (Apple). One ↓ → Banana.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(picked, 'Banana');
    // Overlay is gone after commit.
    expect(find.text('Cherry'), findsNothing);
  });

  testWidgets('Enter on empty results fires onCreateNew', (tester) async {
    String? created;
    await tester.pumpWidget(
      _harness(
        onSearch: (q) async => const <String>[],
        onCreateNew: (q) => created = q,
      ),
    );

    final field = find.byType(TextFormField);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'Durian');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(created, 'Durian');
  });

  testWidgets('Esc closes the overlay without clearing the field',
      (tester) async {
    await tester.pumpWidget(_harness());
    final field = find.byType(TextFormField);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'a');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsNothing);
    // Field text is preserved.
    expect((tester.widget(field) as TextFormField).controller?.text, 'a');
  });

  testWidgets('tap commits the row', (tester) async {
    String? picked;
    await tester.pumpWidget(_harness(onSelected: (v) => picked = v));
    final field = find.byType(TextFormField);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'a');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cherry'));
    await tester.pumpAndSettle();

    expect(picked, 'Cherry');
  });
}
