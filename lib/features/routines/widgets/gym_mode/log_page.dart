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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:wger/core/consts.dart';
import 'package:wger/core/formatting/formatting.dart';
import 'package:wger/core/i18n.dart';
import 'package:wger/core/snackbar.dart';
import 'package:wger/core/widgets/core.dart';
import 'package:wger/core/widgets/error.dart';
import 'package:wger/features/exercises/models/exercise.dart';
import 'package:wger/features/routines/models/log.dart';
import 'package:wger/features/routines/models/repetition_unit.dart';
import 'package:wger/features/routines/models/set_config_data.dart';
import 'package:wger/features/routines/models/slot_entry.dart';
import 'package:wger/features/routines/models/weight_unit.dart';
import 'package:wger/features/routines/providers/gym_log_notifier.dart';
import 'package:wger/features/routines/providers/gym_state.dart';
import 'package:wger/features/routines/providers/gym_state_notifier.dart';
import 'package:wger/features/routines/providers/plate_weights.dart';
import 'package:wger/features/routines/providers/routines_notifier.dart';
import 'package:wger/features/routines/providers/workout_logs_notifier.dart';
import 'package:wger/features/routines/screens/settings_plates_screen.dart';
import 'package:wger/features/routines/validators.dart';
import 'package:wger/features/routines/widgets/forms/rir.dart';
import 'package:wger/features/routines/widgets/forms/slide_adjust_number_field.dart';
import 'package:wger/features/routines/widgets/gym_mode/navigation.dart';
import 'package:wger/features/routines/widgets/plate_calculator.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

class LogPage extends ConsumerWidget {
  final _logger = Logger('LogPage');

  final PageController _controller;

  /// Identifies which slot page this widget renders, so it shows its own
  /// content instead of whatever the globally-current page happens to be.
  final String slotUuid;

  LogPage(this._controller, this.slotUuid);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gymState = ref.watch(gymStateProvider);
    final languageCode = Localizations.localeOf(context).languageCode;

    final slotEntryPage = gymState.getSlotPageByUUID(slotUuid);
    if (slotEntryPage == null) {
      _logger.info('getSlotPageByUUID for $slotUuid returned null, showing empty container.');
      return Container();
    }

    final page = gymState.getPageByIndex(slotEntryPage.pageIndex);
    if (page == null) {
      _logger.info(
        'getPageByIndex for ${slotEntryPage.pageIndex} returned null, showing empty container.',
      );
      return Container();
    }
    final setConfigData = slotEntryPage.setConfigData!;

    // Past logs come straight from the local DB (not the gym-mode routine
    // snapshot) so a set logged during this workout shows up right away.
    final pastLogs = ref.watch(
      pastExerciseLogsProvider(
        routineId: gymState.routine.id!,
        exerciseId: setConfigData.exerciseId,
        weeksBack: gymState.logScopeWeeks,
        distinct: gymState.showDistinctLogs,
      ),
    );

    // Mark done sets
    final decorationStyle = slotEntryPage.logDone
        ? TextDecoration.lineThrough
        : TextDecoration.none;

    final logPageCount = page.slotPages.where((e) => e.type == SlotPageType.log).length;

    return Column(
      children: [
        NavigationHeader(
          setConfigData.exercise.getTranslation(languageCode).name,
          _controller,
        ),

        // Set progress: the current set number is the hero, the routine
        // target (e.g. "3 × 100 kg") sits right below it, so the logged
        // value can be compared against the plan at a glance.
        Container(
          color: theme.colorScheme.onInverseSurface,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                '${slotEntryPage.setIndex + 1} / $logPageCount',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                setConfigData.textRepr,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  decoration: decorationStyle,
                ),
              ),
              if (setConfigData.type != SlotEntryType.normal)
                Text(
                  setConfigData.type.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: decorationStyle,
                  ),
                ),
            ],
          ),
        ),
        if (setConfigData.exercise.showPlateCalculator) const LogsPlatesWidget(),
        if (slotEntryPage.setConfigData!.comment.isNotEmpty)
          Text(slotEntryPage.setConfigData!.comment, textAlign: TextAlign.center),
        const SizedBox(height: 10),

        // Overriding the log scope from here is handled in a follow-up, the
        // settings currently only live in the gym mode options.
        // _LogScopeControls(gymState: gymState),
        Expanded(child: _buildPastLogs(pastLogs, setConfigData.exercise)),

        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Card(
            color: Theme.of(context).colorScheme.inversePrimary,
            // color: Theme.of(context).secondaryHeaderColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LogFormWidget(
                controller: _controller,
                configData: setConfigData,
                key: ValueKey('log-form-${slotEntryPage.uuid}'),
              ),
            ),
          ),
        ),
        NavigationFooter(_controller),
      ],
    );
  }

  /// Renders the previous logs for this exercise
  Widget _buildPastLogs(AsyncValue<List<Log>> pastLogs, Exercise exercise) {
    if (pastLogs.hasError) {
      _logger.warning('Could not load past logs', pastLogs.error, pastLogs.stackTrace);
      // Scroll-wrap so the indicator fits this slim slot instead of overflowing.
      return SingleChildScrollView(
        child: StreamErrorIndicator(pastLogs.error!, stacktrace: pastLogs.stackTrace),
      );
    }
    final logs = pastLogs.value ?? const <Log>[];
    return logs.isEmpty
        ? const SizedBox.shrink()
        : LogsPastLogsWidget(pastLogs: logs, exercise: exercise);
  }
}

class LogsPlatesWidget extends ConsumerWidget {
  const LogsPlatesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plateWeightsState = ref.watch(plateCalculatorProvider);

    return Container(
      color: Theme.of(context).colorScheme.onInverseSurface,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed(ConfigurePlatesScreen.routeName);
            },
            child: SizedBox(
              child: plateWeightsState.hasPlates
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...plateWeightsState.calculatePlates.entries.map(
                          (entry) => Row(
                            children: [
                              Text(entry.value.toString()),
                              const Text('×'),
                              PlateWeight(
                                value: entry.key,
                                size: 37,
                                padding: 2,
                                margin: 0,
                                color: ref.read(plateCalculatorProvider).getColor(entry.key),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: MutedText(
                        AppLocalizations.of(context).plateCalculatorNotDivisible,
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 3),
        ],
      ),
    );
  }
}

class LogsPastLogsWidget extends ConsumerWidget {
  final List<Log> pastLogs;

  /// The exercise the logs belong to, they only carry its ID
  final Exercise exercise;

  const LogsPastLogsWidget({
    super.key,
    required this.pastLogs,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logProvider = ref.read(gymLogProvider.notifier);
    final dateFormat = localizedDate(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              AppLocalizations.of(context).labelWorkoutLogs,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          ...pastLogs.map((pastLog) {
            return ListTile(
              key: ValueKey('past-log-${pastLog.id}'),
              dense: true,
              leading: const Icon(Icons.history, size: 20),
              title: Text(
                pastLog.repTextNoNl(context),
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(dateFormat.format(pastLog.date)),
              trailing: const Icon(Icons.copy, size: 20),
              onTap: () {
                logProvider.setLog(pastLog, exercise: exercise);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                showSnackbar(context, AppLocalizations.of(context).dataCopied);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            );
          }),
        ],
      ),
    );
  }
}

class LogFormWidget extends ConsumerStatefulWidget {
  final PageController controller;
  final SetConfigData configData;

  const LogFormWidget({
    super.key,
    required this.controller,
    required this.configData,
  });

  @override
  _LogFormWidgetState createState() => _LogFormWidgetState();
}

class _LogFormWidgetState extends ConsumerState<LogFormWidget> {
  final _form = GlobalKey<FormState>();

  /// Whether the draft has already been pre-filled from the previous session.
  /// The pre-fill runs exactly once per log page (the form state is keyed by
  /// the slot page uuid, so it re-arms when the page is revisited).
  bool _didAutoFill = false;

  /// Whether the user has manually adjusted weight/reps. Once the user takes
  /// over, the previous-session pre-fill is skipped so their input wins.
  bool _userTouched = false;

  /// Compact unit dropdown used by the slide-adjust fields.
  ///
  /// Mirrors the selector the previous form widgets rendered internally; the
  /// slide-adjust field itself stays decoupled from the unit models/providers.
  Widget? _buildUnitSelector<T>({
    required List<T> units,
    required String tooltip,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) {
    if (units.isEmpty) {
      return null;
    }
    return PopupMenuButton<T>(
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => units
          .map((u) => PopupMenuItem<T>(value: u, child: Text(label(u))))
          .toList(),
    );
  }

  /// Pre-fills the draft with the most recent weight/reps logged for this
  /// exercise (quick set entry): one tap on the Log button then re-logs the
  /// previous performance. The routine's target values stay as the targets;
  /// the slide-adjust fields remain available for corrections.
  void _applyAutoFill(Log latest) {
    if (_userTouched) {
      return;
    }
    final current = ref.read(gymLogProvider);
    if (current == null) {
      return;
    }
    final prefill = current.copyWith(
      weight: latest.weight,
      repetitions: latest.repetitions,
      weightUnitObj: latest.weightUnitObj,
      repetitionsUnitObj: latest.repetitionsUnitObj,
    );
    ref.read(gymLogProvider.notifier).setLog(prefill);
  }

  Future<void> _save() async {
    final i18n = AppLocalizations.of(context);
    final form = _form.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    form.save();

    final log = ref.read(gymLogProvider);
    if (log == null) {
      return;
    }
    final error = validateWorkoutLogCrossField(
      repetitions: log.repetitions,
      weight: log.weight,
      i18n: i18n,
    );
    if (error != null) {
      showSnackbar(context, error);
      return;
    }

    final gymState = ref.read(gymStateProvider);
    final gymProvider = ref.read(gymStateProvider.notifier);
    final page = gymState.getSlotEntryPageByIndex()!;

    // A failed write is intentionally left to propagate to the global
    // error handler; the success path below is then skipped.
    await ref.read(workoutLogProvider).addEntry(log);
    if (!context.mounted) {
      return;
    }

    gymProvider.markSlotPageAsDone(page.uuid, isDone: true);
    // Best-effort haptic: unavailable in tests and on some desktop platforms.
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Haptics are best-effort; swallow plugin failures.
    }
    showSnackbar(
      context,
      i18n.successfullySaved,
      center: true,
      duration: const Duration(seconds: 2),
    );
    widget.controller.nextPage(
      duration: DEFAULT_ANIMATION_DURATION,
      curve: DEFAULT_ANIMATION_CURVE,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final log = ref.watch(gymLogProvider);

    // One-shot pre-fill: the latest past log for this exercise becomes the
    // default weight/reps as soon as it is available. The same provider
    // powers the past-log list above, so no extra query is issued.
    final gymState = ref.watch(gymStateProvider);
    final pastLogs = ref.watch(
      pastExerciseLogsProvider(
        routineId: gymState.routine.id!,
        exerciseId: widget.configData.exerciseId,
        weeksBack: gymState.logScopeWeeks,
        distinct: gymState.showDistinctLogs,
      ),
    );
    if (!_didAutoFill && !_userTouched && pastLogs.hasValue) {
      final logs = pastLogs.value ?? const <Log>[];
      if (logs.isNotEmpty) {
        _didAutoFill = true;
        final latest = logs.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_userTouched) {
            _applyAutoFill(latest);
          }
        });
      }
    }

    // The log is populated when the page becomes current: the PageView can lay
    // out and mount this page before that happens, so guard against null.
    if (log == null) {
      return const SizedBox.shrink();
    }

    return Form(
      key: _form,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SlideAdjustNumberField(
                  key: const ValueKey('logs-reps-widget'),
                  value: log.repetitions,
                  step: widget.configData.repetitionsRounding ?? 1,
                  decimals: 0,
                  label: i18n.repetitions,
                  // The default 'repetitions' unit is implied by the label;
                  // only render a non-default unit next to the value.
                  unitLabel: log.repetitionsUnitObj != null &&
                          log.repetitionsUnitObj!.id != REP_UNIT_REPETITIONS_ID
                      ? getServerStringTranslation(log.repetitionsUnitObj!.name, context)
                      : null,
                  unitSelector: _buildUnitSelector(
                    tooltip: i18n.repetitionUnit,
                    units:
                        ref.watch(routineRepetitionUnitProvider).asData?.value ??
                            const <RepetitionUnit>[],
                    label: (u) => getServerStringTranslation(u.name, context),
                    onSelected: (v) {
                      ref.read(gymLogProvider.notifier).setRepetitionUnit(v);
                    },
                  ),
                  onChanged: (v) {
                    _userTouched = true;
                    if (v != null) {
                      ref.read(gymLogProvider.notifier).setRepetitions(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SlideAdjustNumberField(
                  key: const ValueKey('logs-weight-widget'),
                  value: log.weight,
                  step: widget.configData.weightRounding ?? 0.5,
                  decimals: 2,
                  label: i18n.weight,
                  unitLabel: log.weightUnitObj != null
                      ? getServerStringTranslation(log.weightUnitObj!.name, context)
                      : null,
                  unitSelector: _buildUnitSelector(
                    tooltip: i18n.weightUnit,
                    units: ref.watch(routineWeightUnitProvider).asData?.value ??
                        const <WeightUnit>[],
                    label: (u) => getServerStringTranslation(u.name, context),
                    onSelected: (v) {
                      ref.read(gymLogProvider.notifier).setWeightUnit(v);
                    },
                  ),
                  onChanged: (v) {
                    _userTouched = true;
                    if (v != null) {
                      ref.read(gymLogProvider.notifier).setWeight(v);
                      ref.read(plateCalculatorProvider.notifier).setWeight(v);
                    }
                  },
                ),
              ),
            ],
          ),
          RiRInputWidget(
            key: const ValueKey('rir-input-widget'),
            log.rir,
            onChanged: (value) {
              log.rir = value == '' ? null : num.parse(value);
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              key: const ValueKey('save-log-button'),
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline, size: 24),
              label: Text(
                i18n.log,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Compact inline controls for overriding the global log-scope settings. Kept
// around for the follow-up that lets the scope be changed from the log page.
//
// class _LogScopeControls extends ConsumerWidget {
//   final GymModeState gymState;
//
//   const _LogScopeControls({required this.gymState});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final gymNotifier = ref.read(gymStateProvider.notifier);
//     final i18n = AppLocalizations.of(context);
//     final theme = Theme.of(context);
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.history, size: 18, color: theme.colorScheme.primary),
//               const SizedBox(width: 4),
//               DropdownButton<int?>(
//                 value: gymState.logScopeWeeks,
//                 isDense: true,
//                 underline: const SizedBox.shrink(),
//                 style: theme.textTheme.bodySmall,
//                 onChanged: (value) => gymNotifier.setLogScopeWeeks(value),
//                 items: [
//                   DropdownMenuItem<int?>(
//                     value: null,
//                     child: Text(i18n.gymModeLogScopeCurrentRoutine),
//                   ),
//                   ...[8, 12, 25, 50].map(
//                     (w) => DropdownMenuItem<int?>(
//                       value: w,
//                       child: Text(i18n.gymModeLogScopeWeeks(w)),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           Row(
//             children: [
//               Text(i18n.gymModeDistinctLogs, style: theme.textTheme.bodySmall),
//               Switch.adaptive(
//                 value: gymState.showDistinctLogs,
//                 onChanged: (v) => gymNotifier.setShowDistinctLogs(v),
//                 materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
