/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2020 - 2026 wger Team
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wger/core/app_settings_notifier.dart';
import 'package:wger/core/formatting/formatting.dart';
import 'package:wger/core/material.dart';
import 'package:wger/core/network/auth_http_client.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/core/network/wger_base.dart';
import 'package:wger/core/settings_dashboard_widgets_screen.dart';
import 'package:wger/core/widgets/app_bar.dart';
import 'package:wger/core/widgets/dashboard/calendar.dart';
import 'package:wger/core/widgets/dashboard/widgets/measurements.dart';
import 'package:wger/core/widgets/dashboard/widgets/nutrition.dart';
import 'package:wger/core/widgets/dashboard/widgets/routines.dart';
import 'package:wger/core/widgets/dashboard/widgets/trophies.dart';
import 'package:wger/core/widgets/dashboard/widgets/weight.dart';
import 'package:wger/core/widgets/sync_status_dialog.dart';
import 'package:wger/database/powersync/powersync.dart'
    show builtPowerSyncInstance, connectPowerSync, syncStatus, syncWatchdogProvider;
import 'package:wger/l10n/generated/app_localizations.dart';

/// Dashboard header: a large "Today" title with the full date, plus the
/// actions that used to live in the app bar (widget configuration, sync
/// status and the settings menu) so nothing becomes unreachable.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateFormat = localizedDate(context);
    final syncState = ref.watch(syncStatus);
    final status = syncStatusIconAndLabel(syncState, i18n);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.today, style: theme.textTheme.displaySmall),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(DateTime.now()),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 48dp tap targets, same actions as the previous app bar.
          IconButton(
            tooltip: i18n.dashboardWidgets,
            icon: const Icon(Icons.widgets_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(ConfigureDashboardWidgetsScreen.routeName);
            },
          ),
          IconButton(
            tooltip: status.label,
            icon: Icon(status.icon),
            onPressed: () => showDialog<void>(
              context: context,
              // The dialog watches the sync state itself; only the server URL
              // and the offline gate are snapshots taken when it opens.
              builder: (_) => SyncStatusDialog(
                serverUrl: ref.read(wgerBaseProvider).serverUrl,
                onReconnect: !ref.read(networkStatusProvider)
                    ? null
                    : () {
                        final db = builtPowerSyncInstance;
                        final serverUrl = ref.read(wgerBaseProvider).serverUrl;
                        if (db == null || serverUrl == null || !ref.read(networkStatusProvider)) {
                          return;
                        }
                        ref.read(syncWatchdogProvider).reset();
                        connectPowerSync(
                          db,
                          serverUrl,
                          ref.read(authenticatedHttpClientProvider),
                        );
                      },
              ),
            ),
          ),
          IconButton(
            tooltip: i18n.settingsTitle,
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) => const MainSettingsDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const routeName = '/dashboard';

  Widget _getDashboardWidget(DashboardWidget widget) {
    switch (widget) {
      case DashboardWidget.routines:
        return const DashboardRoutineWidget();
      case DashboardWidget.weight:
        return const DashboardWeightWidget();
      case DashboardWidget.measurements:
        return const DashboardMeasurementWidget();
      case DashboardWidget.calendar:
        return const DashboardCalendarWidget();
      case DashboardWidget.nutrition:
        return const DashboardNutritionWidget();
      case DashboardWidget.trophies:
        return const DashboardTrophiesWidget();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < MATERIAL_XS_BREAKPOINT;
    final visibleWidgets = ref.watch(
      appSettingsProvider.select(
        (s) => s.value?.dashboardItems.visibleWidgets ?? const <DashboardWidget>[],
      ),
    );

    final i18n = AppLocalizations.of(context);

    // The routine widget is the hero card: full width, always on top. The
    // remaining widgets form the "Overview" section below.
    final heroVisible = visibleWidgets.contains(DashboardWidget.routines);
    final secondaryWidgets =
        visibleWidgets.where((widget) => widget != DashboardWidget.routines).toList();

    late final int crossAxisCount;
    if (width < MATERIAL_MD_BREAKPOINT) {
      crossAxisCount = 2;
    } else if (width < MATERIAL_LG_BREAKPOINT) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MATERIAL_LG_BREAKPOINT),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const DashboardHeader(),
              if (heroVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: const DashboardRoutineWidget(),
                    ),
                  ),
                ),
              if (secondaryWidgets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    i18n.overview,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              if (isMobile)
                ...secondaryWidgets.map(
                  (widget) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _getDashboardWidget(widget),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GridView.count(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: secondaryWidgets
                        .map(
                          (widget) => SingleChildScrollView(
                            child: _getDashboardWidget(widget),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
