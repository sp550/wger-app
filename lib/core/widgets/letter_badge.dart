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

import 'package:flutter/material.dart';

/// Fixed accent palette used by the presentation-only [LetterBadge]. Kept
/// separate from the theme on purpose: badges use their own accent set so
/// the category initials stay recognizable regardless of the app palette.
const List<Color> letterBadgePalette = <Color>[
  Color(0xFFE8590C), // orange  — shoulders
  Color(0xFF1971C2), // blue    — back
  Color(0xFFC92A2A), // red     — chest
  Color(0xFF2F9E44), // green   — legs
  Color(0xFF6741D9), // violet  — arms
  Color(0xFF0B7285), // teal    — core
  Color(0xFFE67700), // amber   — other
  Color(0xFFA61E4D), // magenta — cardio
];

/// Deterministic, presentation-only color for a badge: a stable hash of the
/// name picks an accent from [letterBadgePalette]. No data, no server round
/// trip — the same name always renders the same badge color.
Color letterBadgeColorFor(String text) {
  var hash = 0;
  for (final unit in text.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return letterBadgePalette[hash % letterBadgePalette.length];
}

/// Colored circular letter badge (category/exercise/routine initial), the
/// visual anchor of list rows in the Progression reference: a fixed accent
/// circle with a white bold initial. Purely presentational, add only.
class LetterBadge extends StatelessWidget {
  const LetterBadge({
    super.key,
    required this.text,
    this.size = 44,
  });

  /// Name the initial and the badge color are derived from.
  final String text;

  /// Outer diameter of the badge circle.
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: letterBadgeColorFor(text),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
