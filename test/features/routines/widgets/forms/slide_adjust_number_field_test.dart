/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2026 wger Team
 *
 * wger Workout Manager is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wger/features/routines/widgets/forms/slide_adjust_number_field.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

/// Stateful harness: the field is a controlled widget, so the harness stores
/// the committed value (like the gym-log provider does) and rebuilds.
class _FieldHarness extends StatefulWidget {
  final num initialValue;
  final num step;
  final List<num?> changes;

  const _FieldHarness({
    required this.initialValue,
    required this.step,
    required this.changes,
  });

  @override
  State<_FieldHarness> createState() => _FieldHarnessState();
}

class _FieldHarnessState extends State<_FieldHarness> {
  late num? value;

  @override
  void initState() {
    super.initState();
    value = widget.initialValue;
  }

  void _onChanged(num? v) {
    widget.changes.add(v);
    setState(() => value = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SlideAdjustNumberField(
          key: const ValueKey('field'),
          value: value,
          step: widget.step,
          label: 'Weight',
          onChanged: _onChanged,
        ),
      ),
    );
  }
}

void main() {
  final scrub = find.byKey(const ValueKey('slide-adjust-scrub'));

  /// The widget displays values through the locale's decimal format with at
  /// most [decimals] fraction digits (trailing zeros stripped).
  String formatted(num value, {int decimals = 2}) =>
      (NumberFormat.decimalPattern('en')..maximumFractionDigits = decimals).format(value);

  Future<void> pumpField(WidgetTester tester, {required _FieldHarness harness}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: harness,
      ),
    );
  }

  group('SlideAdjustNumberField', () {
    testWidgets('dragging up over the value steps it up and commits on release', (tester) async {
      final changes = <num?>[];
      await pumpField(tester, harness: _FieldHarness(initialValue: 10, step: 0.5, changes: changes));

      // Drag well past the touch slop; the committed value must be the
      // initial value plus a whole number of 0.5 steps.
      await tester.drag(scrub, const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(changes, hasLength(1), reason: 'value is committed once, on release');
      final committed = changes.single!;
      expect(committed, greaterThan(10));
      expect((committed - 10) % 0.5, 0);
      // The field reflects the committed value (localized en formatting).
      expect(find.text(formatted(committed)), findsOneWidget);
    });

    testWidgets('dragging down over the value steps it down', (tester) async {
      final changes = <num?>[];
      await pumpField(tester, harness: _FieldHarness(initialValue: 10, step: 1, changes: changes));

      await tester.drag(scrub, const Offset(0, 100));
      await tester.pumpAndSettle();

      expect(changes, hasLength(1));
      expect(changes.single, lessThan(10));
      expect((10 - changes.single!) % 1, 0);
      expect(find.text(formatted(changes.single!, decimals: 0)), findsOneWidget);
    });

    testWidgets('tapping the value opens the manual entry dialog and saves a typed value', (
      tester,
    ) async {
      final changes = <num?>[];
      await pumpField(tester, harness: _FieldHarness(initialValue: 10, step: 1, changes: changes));

      await tester.tap(scrub);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '52.5');
      await tester.tap(find.byKey(const ValueKey('slide-adjust-save-button')));
      await tester.pumpAndSettle();

      expect(changes, [52.5]);
      expect(find.text('52.5'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('quick plus button steps by the configured step', (tester) async {
      final changes = <num?>[];
      await pumpField(tester, harness: _FieldHarness(initialValue: 0, step: 0.5, changes: changes));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(changes, [0.5]);
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('value never steps below zero', (tester) async {
      final changes = <num?>[];
      await pumpField(tester, harness: _FieldHarness(initialValue: 1, step: 1, changes: changes));

      // A large downward drag would go negative; the value clamps at 0.
      await tester.drag(scrub, const Offset(0, 100));
      await tester.pumpAndSettle();

      expect(changes, [0]);
      expect(find.text('0'), findsOneWidget);
    });
  });
}
