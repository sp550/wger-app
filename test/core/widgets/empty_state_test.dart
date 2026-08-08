/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c)  2026 wger Team
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
import 'package:wger/core/widgets/empty_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('EmptyState', () {
    testWidgets('renders icon, title, subtitle and no action without a callback', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here yet',
            subtitle: 'Tap below to get started',
            actionLabel: 'Create',
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Tap below to get started'), findsOneWidget);
      // actionLabel without onAction: no button is rendered.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('tapping the action button invokes onAction', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          EmptyState(
            icon: Icons.add,
            title: 'Empty',
            actionLabel: 'Add',
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text('Add'));
      expect(tapped, isTrue);
    });

    testWidgets('renders with only a title and the default icon', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(title: 'Nothing here')));

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
