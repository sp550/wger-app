/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2026 wger Team
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wger/core/consts.dart';
import 'package:wger/core/form_validators.dart';
import 'package:wger/core/formatting/formatting.dart';
import 'package:wger/core/number_input.dart';
import 'package:wger/features/routines/models/log.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

/// Sentinel popped by the manual-entry dialog when the user cleared the field.
const Object _clearedValue = Object();

/// Large, drag-to-adjust numeric input used in the gym-mode logging flow.
///
/// The current value is shown big and legible (design pillar: sizing
/// hierarchy). The user adjusts it by
///
///  * tapping the number and sliding vertically - dragging up increases the
///    value in [step] increments, dragging down decreases it. Every step
///    triggers a selection haptic and the value is committed through
///    [onChanged] when the gesture is released, or
///  * tapping the number or the keyboard button, which opens a precise manual
///    numeric entry dialog (the previous keyboard-only input remains as a
///    fallback).
///
/// Optional quick +/- buttons use the same [step]. The drag surface is at
/// least 56dp tall (>= the 48dp comfortable touch-target guideline) and the
/// widget uses theme colors, so it fits the app's dark-first design.
class SlideAdjustNumberField extends StatefulWidget {
  /// Current value, `null` renders a muted placeholder.
  final num? value;

  /// Called with the new value when a drag gesture is released or the manual
  /// entry is confirmed. Never called mid-gesture.
  final ValueChanged<num?> onChanged;

  /// Step size applied per drag step / quick button press.
  final num step;

  /// Semantic label shown above the value (e.g. "Weight", "Repetitions").
  final String label;

  /// Short unit label rendered next to the value (e.g. "kg"). Optional.
  final String? unitLabel;

  /// Optional widget for choosing the unit (e.g. a [PopupMenuButton]); shown
  /// in the top-right corner of the field.
  final Widget? unitSelector;

  /// Smallest allowed value (clamped on adjust), defaults to 0.
  final double minValue;

  /// Largest allowed value (clamped on adjust), defaults to [Log.MAX_VALUE].
  final double maxValue;

  /// How many fraction digits the value is displayed and stepped with.
  final int decimals;

  const SlideAdjustNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.step,
    required this.label,
    this.unitLabel,
    this.unitSelector,
    this.minValue = 0,
    this.maxValue = Log.MAX_VALUE,
    this.decimals = 2,
  });

  @override
  State<SlideAdjustNumberField> createState() => _SlideAdjustNumberFieldState();
}

class _SlideAdjustNumberFieldState extends State<SlideAdjustNumberField> {
  /// Drag distance (in logical pixels) that advances the value by one step.
  static const double _pixelsPerStep = 12;

  late NumberFormat _numberFormat;

  /// Working value while a drag gesture is in progress, `null` when idle.
  double? _dragValue;

  /// Fraction of a step still owed to the gesture.
  double _dragAccumulator = 0;

  @override
  void initState() {
    super.initState();
    // Finalised in didChangeDependencies once the locale is available.
    _numberFormat = NumberFormat.decimalPattern();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _numberFormat = localizedNumberFormat(context)..maximumFractionDigits = widget.decimals;
  }

  /// The value currently on screen: the drag working value, else the widget's
  /// committed [SlideAdjustNumberField.value].
  num? get _displayValue => _dragValue ?? widget.value;

  String get _displayText {
    final value = _displayValue;
    if (value == null) {
      return '—';
    }
    return _numberFormat.format(value);
  }

  /// Rounds [value] to the field's decimal count so repeated steps never
  /// accumulate floating-point noise.
  double _quantize(double value) {
    final factor = math.pow(10, widget.decimals).toDouble();
    return (value * factor).roundToDouble() / factor;
  }

  double _clamp(double value) {
    if (value < widget.minValue) {
      return widget.minValue;
    }
    if (value > widget.maxValue) {
      return widget.maxValue;
    }
    return value;
  }

  void _onDragStart(DragStartDetails details) {
    // Drags never start below zero even if the field was cleared.
    _dragValue = widget.value?.toDouble() ?? 0;
    _dragAccumulator = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final dragValue = _dragValue;
    if (dragValue == null) {
      return;
    }
    _dragAccumulator += details.delta.dy;
    // Dragging up (negative dy) increases the value, dragging down decreases it.
    final steps = (_dragAccumulator / _pixelsPerStep).truncate();
    if (steps == 0) {
      return;
    }
    _dragAccumulator -= steps * _pixelsPerStep;
    final next = _quantize(_clamp(dragValue - steps * widget.step.toDouble()));
    if (next == dragValue) {
      return;
    }
    setState(() => _dragValue = next);
    HapticFeedback.selectionClick();
  }

  void _onDragEnd(DragEndDetails details) {
    final dragValue = _dragValue;
    _dragValue = null;
    _dragAccumulator = 0;
    if (dragValue != null && dragValue != widget.value) {
      widget.onChanged(dragValue);
    }
  }

  void _onDragCancel() {
    _dragValue = null;
    _dragAccumulator = 0;
  }

  /// Applies one [-1|+1] step from the committed value (quick buttons).
  void _stepBy(int direction) {
    final base = widget.value?.toDouble() ?? 0;
    final next = _quantize(_clamp(base + direction * widget.step.toDouble()));
    if (next == base) {
      return;
    }
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  /// Opens the precise manual entry dialog; the fallback for typing.
  Future<void> _openManualEntry() async {
    final result = await showDialog<Object>(
      context: context,
      builder: (context) => _SlideAdjustNumberEntryDialog(
        title: widget.label,
        unitLabel: widget.unitLabel,
        initialValue: _displayValue,
        numberFormat: _numberFormat,
        maxValue: widget.maxValue,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (identical(result, _clearedValue)) {
      widget.onChanged(null);
    } else if (result is num) {
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppLocalizations.of(context);
    final valueText = _displayText;
    final isPlaceholder = _displayValue == null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.unitSelector != null) widget.unitSelector!,
            ],
          ),
          const SizedBox(height: 4),
          // Big value: the whole surface is the tap + vertical-scrub target.
          Semantics(
            label: widget.label,
            value: valueText,
            child: GestureDetector(
              key: const ValueKey('slide-adjust-scrub'),
              behavior: HitTestBehavior.opaque,
              onTap: _openManualEntry,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onVerticalDragCancel: _onDragCancel,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        valueText,
                        maxLines: 1,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: isPlaceholder
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.unitLabel != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        widget.unitLabel!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Quick controls: step down, manual entry, step up.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.remove,
                tooltip: i18n.decrease,
                onTap: () => _stepBy(-1),
              ),
              _ControlButton(
                icon: Icons.keyboard_alt_outlined,
                tooltip: i18n.enterValue,
                onTap: _openManualEntry,
              ),
              _ControlButton(
                icon: Icons.add,
                tooltip: i18n.increase,
                onTap: () => _stepBy(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact round button used for the quick controls under the value.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onTap,
    );
  }
}

/// Precise keyboard entry for [SlideAdjustNumberField].
///
/// A small form dialog with a locale-aware decimal field. Saving an empty
/// field pops [_clearedValue] (value is cleared), otherwise the parsed number
/// is returned and committed by the parent field.
class _SlideAdjustNumberEntryDialog extends StatefulWidget {
  final String title;
  final String? unitLabel;
  final num? initialValue;
  final NumberFormat numberFormat;
  final double maxValue;

  const _SlideAdjustNumberEntryDialog({
    required this.title,
    required this.unitLabel,
    required this.initialValue,
    required this.numberFormat,
    required this.maxValue,
  });

  @override
  State<_SlideAdjustNumberEntryDialog> createState() => _SlideAdjustNumberEntryDialogState();
}

class _SlideAdjustNumberEntryDialogState extends State<_SlideAdjustNumberEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _controller = TextEditingController(
      text: initial == null ? '' : widget.numberFormat.format(initial),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? _clearedValue : widget.numberFormat.parse(text));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('slide-adjust-entry-field'),
          controller: _controller,
          autofocus: true,
          keyboardType: textInputTypeDecimal,
          inputFormatters: [
            LocalizedDecimalInputFormatter(widget.numberFormat.symbols.DECIMAL_SEP),
          ],
          decoration: InputDecoration(
            labelText: widget.title,
            suffixText: widget.unitLabel,
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: (text) =>
              validateOptionalDecimal(text, widget.numberFormat, context, max: widget.maxValue),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('slide-adjust-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('slide-adjust-save-button'),
          onPressed: _submit,
          child: Text(i18n.save),
        ),
      ],
    );
  }
}
