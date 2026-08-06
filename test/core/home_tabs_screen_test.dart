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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:wger/core/app_settings_notifier.dart';
import 'package:wger/core/home_tabs_screen.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/features/routines/models/routine.dart';
import 'package:wger/features/routines/providers/routines_notifier.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

import '../../test_data/routines.dart';

/// Feeds a fixed [RoutinesState] into the widget without touching the repo or
/// the reference-data streams the real notifier builds on.
class _StubRoutinesRiverpod extends RoutinesRiverpod {
  _StubRoutinesRiverpod(this._routines);

  final List<Routine> _routines;

  @override
  Stream<RoutinesState> build() => Stream.value(RoutinesState(routines: _routines));
}

void main() {
  setUp(() async {
    // App settings (dashboard widget configuration, theme mode, ...) read
    // SharedPreferences; use the in-memory implementation like other tests.
    final prefs = InMemorySharedPreferencesAsync.empty();
    // Turn off every configurable dashboard widget so this navigation test
    // only exercises the header + tab shell (the hero card has its own suite).
    await prefs.setString(PREFS_DASHBOARD_CONFIG, '[]');
    SharedPreferencesAsyncPlatform.instance = prefs;
  });

  Widget renderHomeTabs() {
    final container = ProviderContainer.test(
      overrides: [
        networkStatusProvider.overrideWithValue(true),
        // The dashboard header shows the sync status icon; keep the PowerSync
        // instance pending so no native database is created in the test.
        powerSyncInstanceProvider.overrideWith((ref) => Completer<PowerSyncDatabase>().future),
        routinesRiverpodProvider.overrideWith(() => _StubRoutinesRiverpod([getTestRoutine()])),
      ],
    );
    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeTabsScreen(),
      ),
    );
  }

  testWidgets('bottom navigation shows labelled destinations and switches tabs', (tester) async {
    // Phone-sized surface so the narrow-screen bottom bar (not the rail) is used.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(renderHomeTabs());
    // Bounded pumps instead of pumpAndSettle: some offstage tabs (nutrition,
    // weight) show progress spinners while their PowerSync-backed providers
    // stay pending, so no frame settle ever happens.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // The navigation bar is the obvious bottom bar with always-visible labels
    // and a comfortable height for >= 48dp tap targets.
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
    expect(navBar.height, 72);
    // All five destinations, in order, with visible labels.
    expect(
      navBar.destinations.map((d) => d.label).toList(),
      ['Dashboard', 'Workout', 'Nutrition', 'Weight', 'Gallery'],
    );

    // Dashboard tab is selected first and shows the "Today" header.
    expect(find.text('Today'), findsOneWidget);

    // One tap to the workout tab: the routine list is shown.
    await tester.tap(find.text('Workout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('3 day workout'), findsOneWidget);

    // And one tap back to the dashboard: no dead ends, state is preserved.
    await tester.tap(find.text('Dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Today'), findsOneWidget);
  });
}
