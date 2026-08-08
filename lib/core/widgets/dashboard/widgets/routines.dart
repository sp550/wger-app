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

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wger/core/date.dart';
import 'package:wger/core/formatting/formatting.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/core/widgets/async_value_widget.dart';
import 'package:wger/core/widgets/core.dart';
import 'package:wger/core/widgets/dashboard/widgets/nothing_found.dart';
import 'package:wger/core/widgets/error.dart';
import 'package:wger/features/exercises/models/exercise.dart';
import 'package:wger/features/routines/models/day_data.dart';
import 'package:wger/features/routines/models/routine.dart';
import 'package:wger/features/routines/models/set_config_data.dart';
import 'package:wger/features/routines/providers/routines_notifier.dart';
import 'package:wger/features/routines/screens/gym_mode.dart';
import 'package:wger/features/routines/screens/routine_screen.dart';
import 'package:wger/features/routines/widgets/forms/routine.dart';
import 'package:wger/l10n/generated/app_localizations.dart';
import 'package:wger/theme/theme.dart';

/// The hero card of the dashboard: today's workout (or the next scheduled
/// one), with a one-tap "Start" button that drops the user straight into
/// gym mode.
class DashboardRoutineWidget extends ConsumerStatefulWidget {
  const DashboardRoutineWidget();

  @override
  _DashboardRoutineWidgetState createState() => _DashboardRoutineWidgetState();
}

class _DashboardRoutineWidgetState extends ConsumerState<DashboardRoutineWidget> {
  var _showDetail = false;

  /// Renders the dashboard card shell so loading / error / empty / data
  /// states all share the same outline (icon + title) instead of the card
  /// hopping around. The trailing widget changes per state.
  Widget _shell(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
    Widget? child,
  }) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(title, style: Theme.of(context).textTheme.headlineSmall),
            subtitle: Text(subtitle),
            leading: Icon(
              Icons.fitness_center,
              color: Theme.of(context).textTheme.headlineSmall!.color,
            ),
            trailing: trailing,
          ),
          ?child,
        ],
      ),
    );
  }

  /// Starts gym mode for [dayData] (one tap from the dashboard).
  void _startGymMode(BuildContext context, DayData dayData) {
    final day = dayData.day!;
    Navigator.of(context).pushNamed(
      GymModeScreen.routeName,
      arguments: GymModeArguments(
        day.routineId,
        day.id!,
        dayData.iteration,
      ),
    );
  }

  /// Compact exercise summary: one row per exercise, with the set/reps/weight
  /// information right-aligned and legible.
  Widget _buildExerciseSummary(BuildContext context, DayData dayData) {
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    final grouped = <Exercise, List<SetConfigData>>{};
    for (final slot in dayData.slots) {
      for (final config in slot.setConfigs) {
        grouped.putIfAbsent(config.exercise, () => []).add(config);
      }
    }

    return Column(
      children: grouped.entries.map((entry) {
        final name = entry.key.getTranslation(locale).name;
        final detail = entry.value.map((c) => c.textRepr).join(' + ');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  detail,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// The hero card content for a routine with a schedulable day.
  Widget _heroCard(
    BuildContext context, {
    required Routine routine,
    required List<DayData> days,
    required bool isHydrating,
    required bool detailsLocked,
  }) {
    final i18n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateFormat = localizedDate(context);

    // Prefer today's scheduled day. Fall back to the next non-rest day so the
    // card always shows something actionable.
    final today = days.where((d) => d.date.isSameDayAs(DateTime.now())).firstOrNull;
    final heroDay = today ?? days.where((d) => !d.day!.isRest).firstOrNull;
    final isRestDay = today?.day?.isRest ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow + trailing actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.todaysWorkout.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isHydrating)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (detailsLocked)
                  Icon(Icons.cloud_off, color: theme.colorScheme.outline)
                else
                  IconButton(
                    tooltip: i18n.toggleDetails,
                    onPressed: () {
                      setState(() {
                        _showDetail = !_showDetail;
                      });
                    },
                    icon: _showDetail ? const Icon(Icons.info) : const Icon(Icons.info_outline),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isRestDay)
              Text(i18n.restDay, style: theme.textTheme.headlineMedium)
            else
              Text(
                heroDay?.day?.nameWithType ?? routine.name,
                style: theme.textTheme.headlineMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              '${routine.name} · ${dateFormat.format(heroDay?.date ?? routine.start)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (heroDay != null && !isRestDay) _buildExerciseSummary(context, heroDay),
            const SizedBox(height: 16),
            if (heroDay != null && !isRestDay)
              SizedBox(
                width: double.infinity,
                child: PressableScale(
                  child: FilledButton.icon(
                    key: const ValueKey('dashboard-start-workout'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(i18n.start),
                    onPressed: () => _startGymMode(context, heroDay),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: detailsLocked
                  ? null
                  : () {
                      Navigator.of(context).pushNamed(
                        RoutineScreen.routeName,
                        arguments: routine.id,
                      );
                    },
              child: Text(i18n.goToDetailPage),
            ),
            if (_showDetail && !isHydrating && !detailsLocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DetailContentWidget(days, true),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);

    final asyncState = ref.watch(routinesRiverpodProvider);
    final isOnline = ref.watch(networkStatusProvider);

    // Auto-hydrate the current routine once it appears in the sparse list
    //
    // Gate the watch on the routine's own `isHydrated` flag (which lives on the
    // keep-alive routines provider and survives remounts) so a completed load
    // never re-fires. While offline the structure fetch is unavailable, so it
    // is skipped. A reconnect re-runs build and starts the load.
    final currentRoutine = asyncState.value?.currentRoutine;
    final currentId = currentRoutine?.id;
    final hydration = isOnline && currentId != null && !currentRoutine!.isHydrated
        ? ref.watch(routineHydrationProvider(currentId))
        : null;

    // The hero card fades between loading / error / empty / data instead of
    // popping in. Keyed on the state kind so a refresh that keeps the same
    // kind (e.g. hydration finishing) doesn't re-run the cross-fade.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<String>(
          asyncState.when(
            data: (state) => state.currentRoutine == null ? 'hero-empty' : 'hero-data',
            loading: () => 'hero-loading',
            error: (_, _) => 'hero-error',
          ),
        ),
        child: AsyncValueWidget<RoutinesState>(
          value: asyncState,
          loggerName: 'DashboardRoutineWidget',
          loading: _shell(
            context,
            title: i18n.labelWorkoutPlan,
            subtitle: '',
            trailing: const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorBuilder: (e, st) => _shell(
            context,
            title: i18n.labelWorkoutPlan,
            subtitle: i18n.anErrorOccurred,
            trailing: const Icon(Icons.error_outline, color: Colors.red),
            child: StreamErrorIndicator(e, stacktrace: st),
          ),
          data: (state) {
            final routine = state.currentRoutine;

            // Offline and never fetched: the structure is unavailable, so lock
            // the detail UI instead of showing an empty block.
            final detailsLocked = routine != null && !isOnline && !routine.isHydrated;

            if (routine == null) {
              return _shell(
                context,
                title: i18n.labelWorkoutPlan,
                subtitle: '',
                trailing: const SizedBox(),
                child: NothingFound(
                  i18n.noRoutines,
                  i18n.newRoutine,
                  RoutineForm(Routine.empty()),
                ),
              );
            }

            final isHydrating = hydration?.isLoading ?? false;
            final days = routine.dayDataCurrentIterationFiltered;

            // During hydration the day structure is still loading: the hero card
            // shows the routine name plus a spinner instead of exercise rows and
            // the start button (which would have no data to log against yet).
            return _heroCard(
              context,
              routine: routine,
              days: days,
              isHydrating: isHydrating,
              detailsLocked: detailsLocked,
            );
          },
        ),
      ),
    );
  }
}

class DetailContentWidget extends StatelessWidget {
  final List<DayData> dayDataList;
  final bool showDetail;

  const DetailContentWidget(this.dayDataList, this.showDetail, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...dayDataList.where((dayData) => dayData.day != null).map((dayData) {
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    if (dayData.date.isSameDayAs(DateTime.now())) const Icon(Icons.today),
                    Expanded(
                      child: Text(
                        dayData.day == null || dayData.day!.isRest
                            ? AppLocalizations.of(context).restDay
                            : dayData.day!.nameWithType,
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: MutedText(
                        dayData.day != null ? dayData.day!.description : '',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dayData.day == null || dayData.day!.isRest)
                      const Icon(Icons.hotel)
                    else
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        color: wgerPrimaryButtonColor,
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            GymModeScreen.routeName,
                            arguments: GymModeArguments(
                              dayData.day!.routineId,
                              dayData.day!.id!,
                              dayData.iteration,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              ...dayData.slots.map(
                (slotData) => SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...slotData.setConfigs.map(
                        (s) => showDetail
                            ? Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.exercise
                                            .getTranslation(
                                              Localizations.localeOf(context).languageCode,
                                            )
                                            .name,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: MutedText(
                                          s.textRepr,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                            : Container(),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
            ],
          );
        }),
      ],
    );
  }
}
