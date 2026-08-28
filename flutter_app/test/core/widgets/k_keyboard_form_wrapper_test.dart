import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/core/widgets/k_keyboard_form_wrapper.dart';
import 'package:katasticho/core/widgets/k_fast_entry_grid.dart';

void main() {
  group('KKeyboardFormWrapper Tests', () {
    testWidgets('triggers onSubmit on Ctrl+Enter', (tester) async {
      bool submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KKeyboardFormWrapper(
              onSubmit: () => submitted = true,
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(submitted, isTrue);
    });

    testWidgets('triggers onDateJump on F2', (tester) async {
      bool dateJumped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KKeyboardFormWrapper(
              onDateJump: () => dateJumped = true,
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      expect(dateJumped, isTrue);
    });

    testWidgets('triggers onItemPicker on F7', (tester) async {
      bool itemPicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KKeyboardFormWrapper(
              onItemPicker: () => itemPicked = true,
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.f7);
      expect(itemPicked, isTrue);
    });

    testWidgets('triggers onSchemeLookup on F8', (tester) async {
      bool schemeLookedUp = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KKeyboardFormWrapper(
              onSchemeLookup: () => schemeLookedUp = true,
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.f8);
      expect(schemeLookedUp, isTrue);
    });

    testWidgets('triggers onQuickCreate on Alt+C', (tester) async {
      bool quickCreated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KKeyboardFormWrapper(
              onQuickCreate: () => quickCreated = true,
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(quickCreated, isTrue);
    });

    testWidgets('triggers onAddRow on Alt+A', (tester) async {
      bool rowAdded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KKeyboardFormWrapper(
              onAddRow: () => rowAdded = true,
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(rowAdded, isTrue);
    });

    testWidgets('KBillingShortcutBar renders chips and responds to taps', (tester) async {
      bool dateTapped = false;
      bool submitTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KBillingShortcutBar(
              onDateJump: () => dateTapped = true,
              onSubmit: () => submitTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('F2'), findsOneWidget);
      expect(find.text('Ctrl/Cmd Enter'), findsOneWidget);

      await tester.tap(find.text('Date'));
      expect(dateTapped, isTrue);

      await tester.tap(find.text('Save Order'));
      expect(submitTapped, isTrue);
    });
  });
}
