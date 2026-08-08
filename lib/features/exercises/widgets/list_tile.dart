/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (C) 2020, 2021 wger Team
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
import 'package:wger/core/i18n.dart';
import 'package:wger/core/widgets/letter_badge.dart';
import 'package:wger/features/exercises/models/exercise.dart';
import 'package:wger/features/exercises/screens/exercise_screen.dart';

class ExerciseListTile extends StatelessWidget {
  const ExerciseListTile({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final categoryName = getServerStringTranslation(exercise.category.name, context);

    return ListTile(
      leading: LetterBadge(text: categoryName, size: 48),
      title: Text(
        exercise.getTranslation(Localizations.localeOf(context).languageCode).name,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      subtitle: Text(
        '$categoryName / ${exercise.equipment.map((e) => getServerStringTranslation(e.name, context)).toList().join(', ')}',
      ),
      onTap: () {
        Navigator.pushNamed(context, ExerciseDetailScreen.routeName, arguments: exercise);
      },
    );
  }
}
