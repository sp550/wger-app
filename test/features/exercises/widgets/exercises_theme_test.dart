/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2026 - 2026 wger Team
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

/// Dark-mode parity checks for the exercises widgets:
///
/// - the image carousel page dots derive from `onSurface` (previously a
///   hardcoded `Colors.black`, invisible on the dark surface),
/// - the muscle legend uses the theme's `titleSmall` instead of an ad-hoc
///   bold style,
/// - the search field border uses the theme outline instead of `Colors.black`.
///
/// All of them must hold in light *and* dark themes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/features/exercises/models/category.dart';
import 'package:wger/features/exercises/models/equipment.dart';
import 'package:wger/features/exercises/models/exercise.dart';
import 'package:wger/features/exercises/models/image.dart';
import 'package:wger/features/exercises/models/muscle.dart';
import 'package:wger/features/exercises/providers/exercise_repository.dart';
import 'package:wger/features/exercises/providers/exercises_notifier.dart';
import 'package:wger/features/exercises/widgets/exercises.dart';
import 'package:wger/features/exercises/widgets/filter_row.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

import '../../../fake_auth_environment.dart';
import '../../../fake_connectivity.dart';
import 'exercises_theme_test.mocks.dart';

@GenerateMocks([ExerciseRepository])
void main() {
  installFakeConnectivity();
  installFakeAuthEnvironment();

  late MockExerciseRepository mockExerciseRepo;

  setUp(() {
    mockExerciseRepo = MockExerciseRepository();
    when(
      mockExerciseRepo.watchAllDrift(),
    ).thenAnswer((_) => Stream.value(ExerciseState(const <Exercise>[])));
  });

  ExerciseImage buildImage(int id) {
    return ExerciseImage(
      id: id,
      uuid: 'image-$id',
      exerciseId: 1,
      image: 'exercise-images/1/foo-$id.png',
      isMain: id == 1,
      isAiGenerated: false,
      style: ExerciseImageStyle.photo,
      width: 100,
      height: 100,
      created: DateTime(2025),
      lastUpdate: DateTime(2025),
      licenseId: 1,
      licenseTitle: 'CC BY-SA 4.0',
      licenseObjectUrl: 'https://example.com',
      licenseAuthor: null,
      licenseAuthorUrl: 'https://example.com',
      licenseDerivativeSourceUrl: '',
    );
  }

  Widget wrap(
    Widget child, {
    required Brightness brightness,
    List<Override> overrides = const [],
  }) {
    final theme = ThemeData(brightness: brightness);
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    group('in ${brightness.name} mode', () {
      testWidgets('carousel page dots use the onSurface palette', (tester) async {
        await tester.pumpWidget(
          wrap(
            CarouselImages(images: [buildImage(1), buildImage(2)]),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        final theme = Theme.of(tester.element(find.byType(CarouselImages)));

        // The page dots are the circular AnimatedContainers the widget draws
        // itself; filter them out so carousel-internal containers don't matter.
        final dots = find
            .descendant(
              of: find.byType(CarouselImages),
              matching: find.byType(AnimatedContainer),
            )
            .evaluate()
            .map((e) => e.widget as AnimatedContainer)
            .where(
              (c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration! as BoxDecoration).shape == BoxShape.circle,
            )
            .toList();
        expect(dots, hasLength(2));

        final activeDecoration = dots.first.decoration! as BoxDecoration;
        final inactiveDecoration = dots.last.decoration! as BoxDecoration;
        expect(activeDecoration.color, theme.colorScheme.onSurface);
        expect(
          inactiveDecoration.color,
          theme.colorScheme.onSurface.withValues(alpha: 0.26),
        );
      });

      testWidgets('muscle legend uses the theme titleSmall style', (tester) async {
        await tester.pumpWidget(
          wrap(
            Column(
              children: const [
                MuscleColorHelper(),
                MuscleColorHelper(main: false),
              ],
            ),
            brightness: brightness,
          ),
        );
        await tester.pump();

        final theme = Theme.of(tester.element(find.text('Muscles')));
        final text = tester.widget<Text>(find.text('Muscles'));
        expect(text.style, theme.textTheme.titleSmall);
      });

      testWidgets('exercise search border uses the theme outline', (tester) async {
        await tester.pumpWidget(
          wrap(
            const FilterRow(),
            brightness: brightness,
            overrides: [
              networkStatusProvider.overrideWithValue(true),
              exerciseRepositoryProvider.overrideWithValue(mockExerciseRepo),
              exerciseMusclesProvider.overrideWith(
                (ref) => Stream<List<Muscle>>.value(const <Muscle>[]),
              ),
              exerciseCategoriesProvider.overrideWith(
                (ref) => Stream<List<ExerciseCategory>>.value(const <ExerciseCategory>[]),
              ),
              exerciseEquipmentProvider.overrideWith(
                (ref) => Stream<List<Equipment>>.value(const <Equipment>[]),
              ),
            ],
          ),
        );
        await tester.pump();

        final theme = Theme.of(tester.element(find.byType(FilterRow)));
        final field = tester.widget<TextFormField>(find.byType(TextFormField));
        final border = field.decoration!.border! as OutlineInputBorder;
        expect(border.borderSide.color, theme.colorScheme.outline);
      });
    });
  }
}
