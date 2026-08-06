/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2025 - 2026 wger Team
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

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wger/features/routines/widgets/gym_mode/rest_timer.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpOverlay(
    WidgetTester tester, {
    required Duration duration,
    bool alertOnFinish = true,
    required VoidCallback onDismiss,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              RestTimerOverlay(
                duration: duration,
                alertOnFinish: alertOnFinish,
                onDismiss: onDismiss,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('shows the configured countdown in large digits', (tester) async {
    final now = DateTime(2025, 3, 29, 14, 33);

    await withClock(Clock.fixed(now), () async {
      await pumpOverlay(
        tester,
        duration: const Duration(seconds: 90),
        onDismiss: () {},
      );

      expect(find.byType(RestTimerOverlay), findsOneWidget);
      expect(find.text('Rest timer'), findsOneWidget);
      expect(find.text('1:30'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  });

  testWidgets('skip button dismisses the overlay', (tester) async {
    var dismissed = false;

    await pumpOverlay(
      tester,
      duration: const Duration(seconds: 90),
      onDismiss: () => dismissed = true,
    );

    await tester.tap(find.byKey(const ValueKey('rest-timer-skip-button')));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets('swiping the bar down dismisses the overlay', (tester) async {
    var dismissed = false;

    await pumpOverlay(
      tester,
      duration: const Duration(seconds: 90),
      onDismiss: () => dismissed = true,
    );

    await tester.drag(find.byType(RestTimerOverlay), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets('countdown end shows the done state and auto-dismisses', (tester) async {
    var dismissed = false;

    // A zero-duration countdown finishes on the very first tick, exercising
    // the finish path (haptic/alert + auto-dismiss) without waiting minutes.
    await pumpOverlay(
      tester,
      duration: Duration.zero,
      alertOnFinish: true,
      onDismiss: () => dismissed = true,
    );
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    // The overlay removes itself after the default dismiss delay (2.5 s).
    await tester.pump(const Duration(seconds: 3));
    expect(dismissed, isTrue);
  });
}
