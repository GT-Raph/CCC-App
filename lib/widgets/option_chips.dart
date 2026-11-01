import 'package:flutter/material.dart';

import '../theme/ccc_theme.dart';

/// Options to pick from, as chips that wrap onto more lines. At most one can
/// be picked, or several with [multiple]. Tapping a picked option again
/// clears it, so picking is always optional.
class OptionChips<T> extends StatelessWidget {
  const OptionChips({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiple = false,
    super.key,
  });

  /// Each option's value and label, in order.
  final List<(T, String)> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options) _chip(context, value, label),
      ],
    );
  }

  Widget _chip(BuildContext context, T value, String label) {
    final p = context.palette;
    final picked = selected.contains(value);
    return ChoiceChip(
      label: Text(label),
      selected: picked,
      showCheckmark: false,
      onSelected: (pick) => onChanged({
        if (multiple) ...selected.where((other) => other != value),
        if (pick) value,
      }),
      selectedColor: CccColors.primary,
      backgroundColor: p.surface,
      side: BorderSide(color: picked ? CccColors.primary : p.lineStrong),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      labelStyle: TextStyle(
        fontFamily: CccFonts.openSans,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: picked ? CccColors.onPrimary : p.text,
      ),
    );
  }
}
