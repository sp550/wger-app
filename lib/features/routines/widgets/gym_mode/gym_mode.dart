
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

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/core/widgets/error.dart';
import 'package:wger/core/widgets/progress_indicator.dart';
import 'package:wger/features/routines/models/routine.dart';
import 'package:wger/features/routines/providers/gym_state.dart';
import 'package:wger/features/routines/providers/gym_state_notifier.dart';
import 'package:wger/features/routines/providers/routines_notifier.dart';
import 'package:wger/features/routines/screens/gym_mode.dart';

import 'exercise_overview.dart';
import 'log_page.dart';
import 'rest_timer.dart';
import 'session_page.dart';
import 'start_page.dart';
import 'summary.dart';
import 'timer.dart';

class GymMode extends ConsumerStatefulWidget {
  final GymModeArguments _args;
  final _logger = Logger('GymMode');

  GymMode(this._args);

  @override
  ConsumerState<GymMode> createState() => _GymModeState();
}

class _GymModeState extends ConsumerState<GymMode> {
  late Future<int> _initData;
  bool _initialPageJumped = false;
  late final PageController _controller;

  /// Whether the post-set rest timer is currently visible.
  bool _showRestTimer = false;

  /// Bumped on every logged set so the overlay restarts with a fresh
  /// countdown instead of silently keeping the previous run.
  int _restTimerEpoch = 0;

  /// Per-set rest time captured when the set was logged; falls back to the
  /// configured default countdown duration (see [_restTimerDuration]).
  num? _restTimerSeconds;

  /// Shows the rest timer after a set was logged. [restTime] is the rest
  /// time of the set that was just logged (seconds), if it has one.
  void _onSetLogged(num? restTime) {
    if (!mounted) {
      return;
    }
    setState(() {
      _restTimerEpoch++;
      _restTimerSeconds = restTime;
      _showRestTimer = true;
    });
  }

  /// Countdown time for the rest timer: the per-set rest time wins, then the
  /// configured default countdown duration, with a sensible 90 s fallback.
  Duration get _restTimerDuration {
    final gymState = ref.read(gymStateProvider);
    final seconds = _restTimerSeconds ??
        (gymState.countdownDuration.inSeconds > 0
            ? gymState.countdownDuration.inSeconds
            : 90);
    return Duration(seconds: seconds.toInt() > 0 ? seconds.toInt() : 90);
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 0);
    _initData = _loadGymState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<int> _loadGymState() async {
    widget._logger.fine('Loading gym state');
    // This runs from initState. Yield once so the body never executes
    // synchronously inside the widget life-cycle: the offline branch reaches
    // gym-state mutations with no await in between, and modifying a provider
    // during a life-cycle is not allowed.
    await Future<void>.delayed(Duration.zero);

    final notifier = ref.read(routinesRiverpodProvider.notifier);
    final routineId = widget._args.routineId;

    // The locally-cached routine (drift), if available and previously
    // hydrated. Used as an offline fallback when the server is unreachable.
    Routine? cachedRoutine() => ref
        .read(routinesRiverpodProvider)
        .value
        ?.routines
        .firstWhereOrNull((r) => r.id == routineId);

    final Routine routine;
    if (ref.read(networkStatusProvider)) {
      try {
        routine = await notifier.fetchAndSetRoutineFull(routineId);
      } catch (_) {
        // Server unreachable or timed out: fall back to the locally-cached
        // routine so training can continue offline.
        final cached = cachedRoutine();
        if (cached == null || !cached.isHydrated) {
          rethrow;
        }
        routine = cached;
      }
    } else {
      // Offline: use the local routine data. Reaching the gym mode requires an
      // already-downloaded routine, so the routine is normally present
      final cached = cachedRoutine();
      if (cached == null || !cached.isHydrated) {
        throw StateError('Routine $routineId is not available offline');
      }
      routine = cached;
    }

    final gymViewModel = ref.read(gymStateProvider.notifier);
    final initialPage = gymViewModel.initData(
      routine,
      widget._args.dayId,
      widget._args.iteration,
    );
    await gymViewModel.loadPrefs();
    gymViewModel.calculatePages();

    return initialPage;
  }

  List<Widget> _getContent(GymModeState state) {
    final gymState = ref.watch(gymStateProvider);
    final List<Widget> out = [];

    // Workout overview
    out.add(StartPage(_controller));

    // Sets
    for (final page in state.pages) {
      for (final slotPage in page.slotPages) {
        if (slotPage.type == SlotPageType.exerciseOverview) {
          out.add(ExerciseOverview(_controller, slotPage.uuid));
        }

        if (slotPage.type == SlotPageType.log) {
          out.add(
            LogPage(
              _controller,
              slotPage.uuid,
              onSetLogged: () => _onSetLogged(slotPage.setConfigData?.restTime),
            ),
          );
        }

        // Timer. Use rest time from config data if available, otherwise use user settings
        final rest = slotPage.setConfigData?.restTime;
        if (slotPage.type == SlotPageType.timer) {
          out.add(
            (rest != null || gymState.useCountdownBetweenSets)
                ? TimerCountdownWidget(
                    _controller,
                    (rest ?? gymState.countdownDuration.inSeconds).toInt(),
                  )
                : TimerWidget(_controller),
          );
        }
      }
    }

    // End
    out.add(SessionPage(_controller));
    out.add(WorkoutSummary(_controller));

    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _initData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BoxedProgressIndicator();
        } else if (snapshot.hasError) {
          return Center(
            child: StreamErrorIndicator(snapshot.error!, stacktrace: snapshot.stackTrace),
          );
        } else if (snapshot.connectionState == ConnectionState.done) {
          final initialPage = snapshot.data!;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_initialPageJumped && _controller.hasClients) {
              _controller.jumpToPage(initialPage);
              setState(() => _initialPageJumped = true);
            }
          });

          final state = ref.watch(gymStateProvider);
          final children = [
            ..._getContent(state),
          ];

          return Column(
            children: [
              // Rest timer after a logged set. It lives above the PageView
              // in the normal page flow, so it never covers the log controls:
              // the user can keep swiping and logging while it counts down.
              if (_showRestTimer)
                RestTimerOverlay(
                  key: ValueKey('rest-timer-overlay-$_restTimerEpoch'),
                  duration: _restTimerDuration,
                  alertOnFinish: state.alertOnCountdownEnd,
                  onDismiss: () {
                    if (mounted) {
                      setState(() => _showRestTimer = false);
                    }
                  },
                ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) {
                    ref.read(gymStateProvider.notifier).setCurrentPage(page);

                    // Check if the last page is reached
                    if (page == children.length - 1) {
                      widget._logger.finer('Last page reached, clearing gym state');
                      ref.read(gymStateProvider.notifier).clear();
                    }
                  },
                  children: children,
                ),
              ),
            ],
          );
        }

        return const Center(child: Text('Unexpected state'));
      },
    );
  }
}
