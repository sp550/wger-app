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

/// Subtle press feedback for hero/primary actions (the big 56dp buttons and
/// hero cards): the child scales down and dims slightly while pressed and
/// springs back on release, on top of the Material ripple the button already
/// shows. Quick and quiet, and skipped entirely when the user has "remove
/// animations" enabled.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
    this.pressedOpacity = 0.85,
  });

  final Widget child;

  /// Scale applied while the child is pressed.
  final double pressedScale;

  /// Opacity applied while the child is pressed.
  final double pressedOpacity;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pressed = _pressed && !reduceMotion;

    // A raw [Listener] observes the pointer without joining the gesture
    // arena, so the wrapped button keeps its own tap handling (Material
    // ripple + onPressed) untouched.
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: pressed ? widget.pressedOpacity : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class MutedText extends StatelessWidget {
  final String _text;
  final TextAlign textAlign;
  final TextOverflow? overflow;

  const MutedText(
    this._text, {
    this.textAlign = TextAlign.left,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      style: TextStyle(color: Theme.of(context).colorScheme.outline),
      textAlign: textAlign,
      overflow: overflow,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColorLight.withValues(alpha: 0.15),
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(title),
    );
  }
}

class CircleIconAvatar extends StatelessWidget {
  final double radius;
  final Icon _icon;

  final Color color;

  const CircleIconAvatar(this._icon, {this.radius = 20, this.color = Colors.black12});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: color,
      radius: radius,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50.0),
        child: _icon,
      ),
    );
  }
}
