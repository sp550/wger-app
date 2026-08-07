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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wger/core/dashboard.dart';
import 'package:wger/core/material.dart';
import 'package:wger/features/gallery/screens/gallery_screen.dart';
import 'package:wger/features/nutrition/screens/nutritional_plans_screen.dart';
import 'package:wger/features/routines/screens/routine_list_screen.dart';
import 'package:wger/features/weight/screens/weight_screen.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

class HomeTabsScreen extends ConsumerStatefulWidget {
  const HomeTabsScreen({super.key});

  static const routeName = '/dashboard2';

  @override
  ConsumerState<HomeTabsScreen> createState() => _HomeTabsScreenState();
}

class _HomeTabsScreenState extends ConsumerState<HomeTabsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isWideScreen = false;

  /// Drives the quick cross-fade between tab destinations. The [IndexedStack]
  /// below keeps every tab alive, so this only fades opacity in — no slide,
  /// no cross-fade jank, no lost scroll position.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1.0,
  );

  late final Animation<double> _tabFadeAnimation = CurvedAnimation(
    parent: _tabFade,
    curve: Curves.easeOutCubic,
  );

  /// The tab bodies are built once and kept alive in an [IndexedStack] so
  /// switching tabs never loses scroll position, form input or loaded data:
  /// no dead ends, no jarring rebuilds.
  late final List<Widget> _screens = [
    const DashboardScreen(),
    const RoutineListScreen(),
    const NutritionalPlansScreen(),
    const WeightScreen(),
    const GalleryScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final size = MediaQuery.sizeOf(context);
    _isWideScreen = size.width > MATERIAL_XS_BREAKPOINT;
  }

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });

    // A fast, quiet fade into the new destination. Skipped entirely when the
    // user has "remove animations" enabled.
    if (MediaQuery.disableAnimationsOf(context)) {
      _tabFade.value = 1.0;
    } else {
      _tabFade.forward(from: 0);
    }

    // Light tactile tick for tab changes. Best-effort: haptics are
    // unavailable in tests and on some desktop platforms.
    try {
      HapticFeedback.selectionClick();
    } catch (_) {
      // Haptics are best-effort; swallow plugin failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: AppLocalizations.of(context).labelDashboard,
      ),
      NavigationDestination(
        icon: const Icon(Icons.fitness_center_outlined),
        selectedIcon: const Icon(Icons.fitness_center),
        label: AppLocalizations.of(context).labelBottomNavWorkout,
      ),
      NavigationDestination(
        icon: const Icon(Icons.restaurant_outlined),
        selectedIcon: const Icon(Icons.restaurant),
        label: AppLocalizations.of(context).labelBottomNavNutrition,
      ),
      NavigationDestination(
        icon: const FaIcon(FontAwesomeIcons.weightScale, size: 20),
        label: AppLocalizations.of(context).weight,
      ),
      NavigationDestination(
        icon: const Icon(Icons.photo_library_outlined),
        selectedIcon: const Icon(Icons.photo_library),
        label: AppLocalizations.of(context).gallery,
      ),
    ];

    /// Navigation bar for narrow screens. Labels stay visible so the tabs are
    /// obvious; the bar is taller for comfortable 48dp+ tap targets.
    Widget getNavigationBar() {
      return NavigationBar(
        height: 72,
        destinations: destinations,
        onDestinationSelected: _onItemTapped,
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      );
    }

    /// Navigation rail for wide screens
    Widget getNavigationRail() {
      return NavigationRail(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        labelType: NavigationRailLabelType.all,
        scrollable: true,
        destinations: destinations
            .map(
              (d) => NavigationRailDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: Text(d.label),
              ),
            )
            .toList(),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          if (_isWideScreen) getNavigationRail(),
          Expanded(
            child: FadeTransition(
              opacity: _tabFadeAnimation,
              child: IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isWideScreen ? null : getNavigationBar(),
    );
  }
}
