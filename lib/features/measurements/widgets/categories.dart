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
import 'package:wger/core/form_screen.dart';
import 'package:wger/core/widgets/async_value_widget.dart';
import 'package:wger/core/widgets/empty_state.dart';
import 'package:wger/features/measurements/models/measurement_category.dart';
import 'package:wger/features/measurements/providers/measurement_notifier.dart';
import 'package:wger/features/measurements/widgets/forms.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

import 'categories_card.dart';

class CategoriesList extends ConsumerWidget {
  const CategoriesList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueWidget<List<MeasurementCategory>>(
      value: ref.watch(measurementProvider),
      loggerName: 'CategoriesList',
      data: (categoriesList) {
        if (categoriesList.isEmpty) {
          final i18n = AppLocalizations.of(context);
          return EmptyState(
            icon: Icons.straighten,
            title: i18n.noMeasurements,
            subtitle: i18n.emptyStateAddMeasurement,
            actionLabel: i18n.newEntry,
            onAction: () {
              Navigator.pushNamed(
                context,
                FormScreen.routeName,
                arguments: FormScreenArguments(
                  i18n.newEntry,
                  const MeasurementCategoryForm(),
                ),
              );
            },
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: categoriesList.length,
          itemBuilder: (context, index) => CategoriesCard(categoriesList[index]),
        );
      },
    );
  }
}
