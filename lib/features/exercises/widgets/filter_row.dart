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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/features/exercises/providers/exercise_filters_notifier.dart';
import 'package:wger/features/exercises/screens/add_exercise_screen.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

import 'filter_modal.dart';

class FilterRow extends ConsumerStatefulWidget {
  const FilterRow({super.key});

  @override
  _FilterRowState createState() => _FilterRowState();
}

class _FilterRowState extends ConsumerState<FilterRow> {
  late final TextEditingController _exerciseNameController;

  @override
  void initState() {
    super.initState();

    final initialSearch = ref.read(exerciseListFiltersProvider).filters.searchTerm;

    _exerciseNameController = TextEditingController(text: initialSearch)
      ..addListener(() {
        final text = _exerciseNameController.text;
        final currentFilters = ref.read(exerciseListFiltersProvider).filters;
        if (currentFilters.searchTerm != text) {
          ref
              .read(exerciseListFiltersProvider.notifier)
              .setFilters(
                currentFilters.copyWith(searchTerm: text),
                Localizations.localeOf(context).languageCode,
              );
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(networkStatusProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _exerciseNameController,
              decoration: InputDecoration(
                hintText: '${AppLocalizations.of(context).exerciseName}...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context).filter,
                onPressed: () async {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    builder: (context) => const ExerciseFilterModalBody(),
                  );
                },
                icon: const Icon(Icons.filter_alt),
              ),
              PopupMenuButton<ExerciseMoreOption>(
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<ExerciseMoreOption>(
                      value: ExerciseMoreOption.ADD_EXERCISE,
                      enabled: isOnline,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppLocalizations.of(context).contributeExercise),
                          if (!isOnline) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.cloud_off,
                              size: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ];
                },
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                onSelected: (ExerciseMoreOption selectedOption) {
                  switch (selectedOption) {
                    case ExerciseMoreOption.ADD_EXERCISE:
                      Navigator.of(context).pushNamed(AddExerciseScreen.routeName);
                      break;
                  }
                },
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    super.dispose();
  }
}

enum ExerciseMoreOption { ADD_EXERCISE }
