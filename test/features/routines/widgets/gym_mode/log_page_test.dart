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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:wger/core/widgets/error.dart';
import 'package:wger/features/exercises/models/exercise.dart';
import 'package:wger/features/routines/models/day_data.dart';
import 'package:wger/features/routines/models/log.dart';
import 'package:wger/features/routines/models/routine.dart';
import 'package:wger/features/routines/models/set_config_data.dart';
import 'package:wger/features/routines/models/slot_data.dart';
import 'package:wger/features/routines/providers/gym_state.dart';
import 'package:wger/features/routines/providers/gym_state_notifier.dart';
import 'package:wger/features/routines/providers/workout_logs_repository.dart';
import 'package:wger/features/routines/widgets/gym_mode/log_page.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

import '../../../../../test_data/exercises.dart';
import '../../../../../test_data/routines.dart' as testdata;
import 'log_page_test.mocks.dart';

/// Strips the exercise off a fixture log, watchLogsByExerciseDrift only joins the units
Log asDriftLog(Log log) =>
    Log(
        id: log.id,
        exerciseId: log.exerciseId,
        iteration: log.iteration,
        slotEntryId: log.slotEntryId,
        routineId: log.routineId,
        sessionId: log.sessionId,
        repetitions: log.repetitions,
        rir: log.rir,
        weight: log.weight,
        date: log.date,
      )
      ..repetitionUnit = log.repetitionsUnitObj
      ..weightUnit = log.weightUnitObj;

@GenerateMocks([WorkoutLogRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogPage tests', () {
    late List<Exercise> testExercises;
    late ProviderContainer container;
    late MockWorkoutLogRepository mockWorkoutLogRepo;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      testExercises = getTestExercises();
      mockWorkoutLogRepo = MockWorkoutLogRepository();
      when(mockWorkoutLogRepo.addLocalDrift(any)).thenAnswer((_) async {});
      // Past logs on the page come from this stream (per exercise); reuse the
      // test routine's logs so the previous-entries assertions keep working.
      when(
        mockWorkoutLogRepo.watchLogsByExerciseDrift(
          routineId: anyNamed('routineId'),
          exerciseId: anyNamed('exerciseId'),
        ),
      ).thenAnswer((invocation) {
        final exerciseId = invocation.namedArguments[#exerciseId] as int;
        return Stream.value(
          testdata.getTestRoutine().filterLogsByExercise(exerciseId).map(asDriftLog).toList(),
        );
      });
      container = ProviderContainer.test(
        overrides: [workoutLogRepositoryProvider.overrideWithValue(mockWorkoutLogRepo)],
      );
    });

    /// Seeds the gym state with [routine] and navigates to the first log page
    /// (index 2: start -> exercise overview -> log). [setCurrentPage] also
    /// seeds gymLogProvider with the log template for that slot.
    void seedLogPage(Routine routine) {
      final notifier = container.read(gymStateProvider.notifier);
      notifier.initData(routine, routine.days.first.id!, 1);
      notifier.setCurrentPage(2);
    }

    Future<void> pumpLogPage(WidgetTester tester, {VoidCallback? onSetLogged}) async {
      // The widget resolves its own slot now, so hand it the uuid of the slot
      // the gym state was seeded on (via setCurrentPage above).
      final slotUuid = container.read(gymStateProvider).getSlotEntryPageByIndex()!.uuid;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // A PageView gives LogPage's PageController something to attach to.
              body: Builder(
                builder: (context) {
                  final controller = PageController();
                  return PageView(
                    controller: controller,
                    children: [LogPage(controller, slotUuid, onSetLogged: onSetLogged)],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('handles null reps/weight without crashing', (tester) async {
      final notifier = container.read(gymStateProvider.notifier);
      final routine = testdata.getTestRoutine();
      routine.dayDataGym = [
        DayData(
          iteration: 1,
          date: DateTime(2024, 11, 01),
          label: '',
          day: routine.dayDataGym.first.day,
          slots: [
            SlotData(
              isSuperset: false,
              exerciseIds: [testExercises[0].id],
              setConfigs: [
                SetConfigData(
                  exerciseId: testExercises[0].id,
                  exercise: testExercises[0],
                  slotEntryId: 1,
                  nrOfSets: 1,
                  repetitions: null,
                  repetitionsUnit: null,
                  weight: null,
                  weightUnit: null,
                  restTime: 120,
                  rir: 1.5,
                  rpe: 8,
                  textRepr: '3x100kg',
                ),
              ],
            ),
          ],
        ),
      ];
      notifier.initData(routine, routine.days.first.id!, 1);
      notifier.setCurrentPage(2);

      expect(notifier.state.getSlotEntryPageByIndex()!.type, SlotPageType.log);
      await pumpLogPage(tester);
      expect(find.byType(LogPage), findsOneWidget);
    });

    testWidgets('renders without crashing for the default slot entry page', (tester) async {
      seedLogPage(testdata.getTestRoutine());
      await pumpLogPage(tester);

      expect(find.byType(LogPage), findsOneWidget);
    });

    testWidgets('copy from past log updates form fields and shows a SnackBar', (tester) async {
      seedLogPage(testdata.getTestRoutine());
      await pumpLogPage(tester);

      final pastLogTile = find.byWidgetPredicate(
        (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('past-log-'),
      );
      expect(pastLogTile, findsWidgets);
      await tester.tap(pastLogTile.first);
      await tester.pumpAndSettle();

      // The past log carries 10 reps / 10 weight, which the slide-adjust
      // fields now display directly instead of text fields.
      final repsField = find.byKey(const ValueKey('logs-reps-widget'));
      final weightField = find.byKey(const ValueKey('logs-weight-widget'));
      expect(find.descendant(of: repsField, matching: find.text('10')), findsOneWidget);
      expect(find.descendant(of: weightField, matching: find.text('10')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows an error indicator when past logs fail to load', (tester) async {
      // Error via a stream event (not a build throw), so riverpod surfaces it
      // as state instead of scheduling a retry timer.
      final controller = StreamController<List<Log>>();
      addTearDown(controller.close);
      when(
        mockWorkoutLogRepo.watchLogsByExerciseDrift(
          routineId: anyNamed('routineId'),
          exerciseId: anyNamed('exerciseId'),
        ),
      ).thenAnswer((_) => controller.stream);

      seedLogPage(testdata.getTestRoutine());
      await pumpLogPage(tester);

      controller.addError(Exception('boom'));
      await tester.pumpAndSettle();

      expect(find.byType(StreamErrorIndicator), findsOneWidget);
    });

    testWidgets('save button persists the entered reps/weight with slot/routine/iteration', (
      tester,
    ) async {
      seedLogPage(testdata.getTestRoutine());
      await pumpLogPage(tester);

      // Precise input happens through the manual-entry dialog: open it from
      // the field's value surface (the tap-to-type fallback) and confirm the
      // typed values.
      Future<void> enterViaDialog(Key fieldKey, String value) async {
        await tester.tap(
          find.descendant(
            of: find.byKey(fieldKey),
            matching: find.byKey(const ValueKey('slide-adjust-scrub')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          value,
        );
        await tester.tap(
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Save')),
        );
        await tester.pumpAndSettle();
      }

      await enterViaDialog(const ValueKey('logs-reps-widget'), '12'); // reps
      await enterViaDialog(const ValueKey('logs-weight-widget'), '34'); // weight

      await tester.tap(find.byKey(const ValueKey('save-log-button')));
      await tester.pumpAndSettle();

      final saved = verify(mockWorkoutLogRepo.addLocalDrift(captureAny)).captured.single as Log;
      final gymState = container.read(gymStateProvider);
      expect(saved.repetitions, 12);
      expect(saved.weight, 34);
      expect(saved.slotEntryId, gymState.getSlotEntryPageByIndex()!.setConfigData!.slotEntryId);
      expect(saved.routineId, gymState.routine.id);
      expect(saved.iteration, gymState.iteration);
    });

    testWidgets('reps chevron steppers increment and decrement the value', (tester) async {
      // No previous logs: the form keeps the routine template values (reps = 0),
      // so the chevron steppers are exercised from a known baseline instead of
      // the auto-filled previous-session values.
      when(
        mockWorkoutLogRepo.watchLogsByExerciseDrift(
          routineId: anyNamed('routineId'),
          exerciseId: anyNamed('exerciseId'),
        ),
      ).thenAnswer((_) => Stream.value(const []));

      final routine = testdata.getTestRoutine();
      routine.dayDataGym[0].slots[0].setConfigs[0].repetitions = 0;
      seedLogPage(routine);
      await pumpLogPage(tester);

      final repsWidget = find.byKey(const ValueKey('logs-reps-widget'));
      expect(repsWidget, findsOneWidget);
      final stepUpBtn = find.descendant(
        of: repsWidget,
        matching: find.byIcon(Icons.keyboard_arrow_up),
      );
      final stepDownBtn = find.descendant(
        of: repsWidget,
        matching: find.byIcon(Icons.keyboard_arrow_down),
      );

      await tester.tap(stepUpBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: repsWidget, matching: find.text('1')), findsOneWidget);

      await tester.tap(stepUpBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: repsWidget, matching: find.text('2')), findsOneWidget);

      await tester.tap(stepDownBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: repsWidget, matching: find.text('1')), findsOneWidget);
    });

    testWidgets('weight chevron steppers increment and decrement the value', (tester) async {
      // See the reps test above: an empty past-log stream keeps the template
      // baseline (weight = 0) so the step behaviour stays deterministic.
      when(
        mockWorkoutLogRepo.watchLogsByExerciseDrift(
          routineId: anyNamed('routineId'),
          exerciseId: anyNamed('exerciseId'),
        ),
      ).thenAnswer((_) => Stream.value(const []));

      final routine = testdata.getTestRoutine();
      routine.dayDataGym[0].slots[0].setConfigs[0].weight = 0;
      seedLogPage(routine);
      await pumpLogPage(tester);

      final weightWidget = find.byKey(const ValueKey('logs-weight-widget'));
      expect(weightWidget, findsOneWidget);
      final stepUpBtn = find.descendant(
        of: weightWidget,
        matching: find.byIcon(Icons.keyboard_arrow_up),
      );
      final stepDownBtn = find.descendant(
        of: weightWidget,
        matching: find.byIcon(Icons.keyboard_arrow_down),
      );

      // No per-exercise rounding is configured for this fixture, so the
      // slide-adjust field falls back to the default 0.5 kg step.
      await tester.tap(stepUpBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: weightWidget, matching: find.text('0.5')), findsOneWidget);

      await tester.tap(stepUpBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: weightWidget, matching: find.text('1')), findsOneWidget);

      await tester.tap(stepDownBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: weightWidget, matching: find.text('0.5')), findsOneWidget);
    });

    testWidgets('pre-fills the form with the previous session weight/reps', (tester) async {
      // Only one past log (10 reps x 10 kg), deterministically the "latest".
      final pastLog = testdata.getTestRoutine().filterLogsByExercise(1).firstWhere(
        (log) => log.repetitions == 10,
      );
      when(
        mockWorkoutLogRepo.watchLogsByExerciseDrift(
          routineId: anyNamed('routineId'),
          exerciseId: anyNamed('exerciseId'),
        ),
      ).thenAnswer((_) => Stream.value([asDriftLog(pastLog)]));

      seedLogPage(testdata.getTestRoutine());
      await pumpLogPage(tester);

      // The routine template says 3 reps x 100 kg, but the previous session's
      // log wins, so a single tap on the Log button re-logs that performance.
      final repsField = find.byKey(const ValueKey('logs-reps-widget'));
      final weightField = find.byKey(const ValueKey('logs-weight-widget'));
      expect(find.descendant(of: repsField, matching: find.text('10')), findsOneWidget);
      expect(find.descendant(of: weightField, matching: find.text('10')), findsOneWidget);
      expect(find.descendant(of: repsField, matching: find.text('3')), findsNothing);
    });

    testWidgets('one tap on Log saves the set at the previous weight/reps', (tester) async {
      final pastLog = testdata.getTestRoutine().filterLogsByExercise(1).firstWhere(
        (log) => log.repetitions == 10,
      );
      when(
        mockWorkoutLogRepo.watchLogsByExerciseDrift(
          routineId: anyNamed('routineId'),
          exerciseId: anyNamed('exerciseId'),
        ),
      ).thenAnswer((_) => Stream.value([asDriftLog(pastLog)]));

      seedLogPage(testdata.getTestRoutine());
      await pumpLogPage(tester);

      // Auto-fill turned the draft into the previous session's set; a single
      // tap logs it and advances without touching the keyboard.
      await tester.tap(find.byKey(const ValueKey('save-log-button')));
      await tester.pumpAndSettle();

      final saved = verify(mockWorkoutLogRepo.addLocalDrift(captureAny)).captured.single as Log;
      final gymState = container.read(gymStateProvider);
      expect(saved.repetitions, 10);
      expect(saved.weight, 10);
      expect(saved.slotEntryId, gymState.getSlotEntryPageByIndex()!.setConfigData!.slotEntryId);
      expect(saved.routineId, gymState.routine.id);
      expect(saved.iteration, gymState.iteration);
    });

    testWidgets('fires onSetLogged once after a successful save', (tester) async {
      // The gym-mode shell listens on this callback to show the rest timer;
      // it must only fire on the save success path (not on validation errors
      // or when no callback is wired up).
      var logged = 0;
      seedLogPage(testdata.getTestRoutine());
      await pumpLogPage(tester, onSetLogged: () => logged++);

      await tester.tap(find.byKey(const ValueKey('save-log-button')));
      await tester.pumpAndSettle();

      expect(logged, 1);
    });
  });
}
