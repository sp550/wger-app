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
import 'package:wger/core/widgets/letter_badge.dart';

void main() {
  test('letterBadgeColorFor is deterministic and picks from the palette', () {
    // Same input, same output.
    expect(letterBadgeColorFor('Shoulders'), letterBadgeColorFor('Shoulders'));
    expect(letterBadgeColorFor('Back'), letterBadgeColorFor('Back'));

    // Different inputs can share a color, but the result is always a palette
    // member.
    expect(letterBadgePalette, contains(letterBadgeColorFor('Chest')));
    expect(letterBadgePalette, contains(letterBadgeColorFor('Anything at all')));
  });

  testWidgets('LetterBadge shows the uppercase initial on a colored circle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LetterBadge(text: 'shoulders', size: 48))),
    );

    final badge = find.byType(LetterBadge);
    final container = tester.widget<Container>(
      find.descendant(of: badge, matching: find.byType(Container)),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, letterBadgeColorFor('shoulders'));

    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('LetterBadge falls back to a question mark for empty text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LetterBadge(text: '   '))),
    );

    expect(find.text('?'), findsOneWidget);
  });
}
