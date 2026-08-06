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

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wger/features/routines/widgets/gym_mode/elapsed_time.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

/// Non-blocking rest timer shown in gym mode after a set is logged.
///
/// Counts down from the configured rest time (per-set rest time, else the
/// gym-mode default countdown duration) in large legible digits. The bar
/// lives in the normal page flow above the log PageView, so no control of the
/// log pages is covered: the user can keep swiping and logging while it runs.
///
/// Dismissal works three ways: tapping "Skip", swiping the bar down, or simply
/// waiting for the countdown to end (it auto-dismisses after [dismissDelay]).
/// When [alertOnFinish] is enabled the finish is announced with a haptic pulse
/// and a system alert sound (best effort, mirrors the gym-mode "notify on
/// countdown end" setting used by the dedicated timer pages).
class RestTimerOverlay extends StatefulWidget {
  const RestTimerOverlay({
    super.key,
    required this.duration,
    required this.onDismiss,
    this.alertOnFinish = true,
    this.dismissDelay = const Duration(milliseconds: 2500),
  });

  /// Total countdown time.
  final Duration duration;

  /// Whether finishing the countdown should fire haptic/system feedback.
  final bool alertOnFinish;

  /// How long the finished ("done") state stays visible before the overlay
  /// removes itself.
  final Duration dismissDelay;

  /// Called whenever the overlay is dismissed (skip, swipe or countdown end).
  final VoidCallback onDismiss;

  @override
  State<RestTimerOverlay> createState() => _RestTimerOverlayState();
}

class _RestTimerOverlayState extends State<RestTimerOverlay> {
  late DateTime _endTime;
  late int _remaining;
  Timer? _uiTimer;
  Timer? _autoDismissTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _endTime = clock.now().add(widget.duration);
    _remaining = _computeRemaining();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Evaluate the first second right after the first frame, so a
    // zero-duration countdown finishes immediately instead of waiting for the
    // first periodic tick.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tick();
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  /// Whole seconds left, rounded up so the configured time is shown on the
  /// first frame (e.g. 3:00 for 180 s) and then counts down per second.
  int _computeRemaining() {
    final remaining = _endTime.difference(clock.now());
    if (remaining <= Duration.zero) {
      return 0;
    }
    return (remaining.inMilliseconds / 1000).ceil();
  }

  void _tick() {
    if (!mounted) {
      return;
    }
    setState(() {
      _remaining = _computeRemaining();
    });
    if (_remaining == 0 && !_finished) {
      _finish();
    }
  }

  void _finish() {
    _finished = true;
    _uiTimer?.cancel();
    if (widget.alertOnFinish) {
      // Best-effort feedback: unavailable in tests and on some platforms.
      try {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // Haptics and sounds are best-effort; swallow plugin failures.
      }
    }
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(widget.dismissDelay, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppLocalizations.of(context);
    final finished = _finished || _remaining == 0;

    return Dismissible(
      key: const ValueKey('rest-timer-dismissible'),
      direction: DismissDirection.down,
      onDismissed: (_) => widget.onDismiss(),
      child: Material(
        color: theme.colorScheme.inversePrimary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                finished ? Icons.check_circle_outline : Icons.timer_outlined,
                color: theme.colorScheme.onInversePrimary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finished ? i18n.done : i18n.restTimer,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onInversePrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      ElapsedWorkoutTimer.format(Duration(seconds: _remaining)),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: theme.colorScheme.onInversePrimary,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: const ValueKey('rest-timer-skip-button'),
                onPressed: widget.onDismiss,
                child: Text(i18n.restTimerSkip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
