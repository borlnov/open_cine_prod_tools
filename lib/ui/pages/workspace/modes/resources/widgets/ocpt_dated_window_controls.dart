// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The controls a **dated window** is edited with, shared by the two sheets that hold one: a
/// person's unavailabilities (`OcptPersonSheetUnavailabilitiesCard`) and a location's availability
/// windows (`OcptLocationSheetAvailabilitiesCard`).
///
/// The two say opposite things — when someone is *not* there, when somewhere *is* free — but they
/// are edited the same way, and a reader moving between the two sheets should not have to learn a
/// second set of controls for the same question.
///
/// Every control here is read-only when its callback is null, Flutter's own "no callback, no
/// affordance" idiom: it then prints its value with no way to change it, which is what a version
/// preview shows.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The window a row falls back to the first time it is switched to [OcptDayPartSlot.custom]: an
/// ordinary working day, so the user narrows a plausible window rather than building one from
/// midnight.
const int ocptDefaultWindowStartMinute = 9 * 60;

/// The end of the window described by [ocptDefaultWindowStartMinute].
const int ocptDefaultWindowEndMinute = 18 * 60;

/// The `from … to …` pair of date buttons of a dated window.
///
/// Both ends are always shown, even when they hold the same date: a one-day window is the same
/// shape as any other, and hiding the second end until it differs would hide the very affordance
/// that makes a range.
class OcptDateRangeControl extends StatelessWidget {
  /// The first date the window covers.
  final DateTime startDate;

  /// The last date the window covers, inclusive.
  final DateTime endDate;

  /// Called when the first date is clicked, or null while it may not be changed.
  final VoidCallback? onStartPressed;

  /// Called when the last date is clicked, or null while it may not be changed.
  final VoidCallback? onEndPressed;

  /// Class constructor
  const OcptDateRangeControl({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(tr.resourcesUnavailabilityFromLabel, style: labelStyle),
        OcptPickedValueButton(
          label: DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(startDate),
          onPressed: onStartPressed,
        ),
        Text(tr.resourcesUnavailabilityToLabel, style: labelStyle),
        OcptPickedValueButton(
          label: DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(endDate),
          onPressed: onEndPressed,
        ),
      ],
    );
  }
}

/// The `09:00 → 18:00` pair of time buttons of a window whose slot is [OcptDayPartSlot.custom].
class OcptTimeWindowControl extends StatelessWidget {
  /// The window's start in minutes from midnight, or null while it has none of its own — the
  /// default window is then shown, which is what switching to a custom slot would seed.
  final int? startMinute;

  /// The window's end in minutes from midnight, or null. See [startMinute].
  final int? endMinute;

  /// Called when the start is clicked, or null while it may not be changed.
  final VoidCallback? onStartPressed;

  /// Called when the end is clicked, or null while it may not be changed.
  final VoidCallback? onEndPressed;

  /// Class constructor
  const OcptTimeWindowControl({
    super.key,
    required this.startMinute,
    required this.endMinute,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      OcptPickedValueButton(
        label: _formatMinute(context, startMinute ?? ocptDefaultWindowStartMinute),
        onPressed: onStartPressed,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text("→", style: Theme.of(context).textTheme.labelSmall),
      ),
      OcptPickedValueButton(
        label: _formatMinute(context, endMinute ?? ocptDefaultWindowEndMinute),
        onPressed: onEndPressed,
      ),
    ],
  );

  /// [minute], counted from midnight, as the platform's own time of day.
  String _formatMinute(BuildContext context, int minute) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
}

/// One value a picker sits behind: the value itself, clickable while [onPressed] is given, plain
/// text otherwise.
class OcptPickedValueButton extends StatelessWidget {
  /// The value shown.
  final String label;

  /// Called when it is clicked, or null while it may not be changed.
  final VoidCallback? onPressed;

  /// Class constructor
  const OcptPickedValueButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    final text = Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );

    if (onPressed == null) {
      return text;
    }

    return InkWell(
      onTap: onPressed,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: text),
    );
  }
}

/// The selector a dated window picks its [OcptDayPartSlot] with: one compact pill per value, the
/// active one tinted `primary`, matching `OcptResourcesTabBar`'s own segmented look.
class OcptDayPartSlotSelector extends StatelessWidget {
  /// The currently selected slot.
  final OcptDayPartSlot value;

  /// Called with the slot picked, or null while it may not be changed: the pills then read the
  /// current value out with no reaction to a tap.
  final ValueChanged<OcptDayPartSlot>? onChanged;

  /// Class constructor
  const OcptDayPartSlotSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final slot in OcptDayPartSlot.values)
          OcptSelectablePill(
            label: ocptDayPartSlotLabel(tr, slot),
            isSelected: slot == value,
            onPressed: onChanged == null ? null : () => onChanged!(slot),
          ),
      ],
    );
  }
}

/// One pill of a compact segmented selector: tinted `primary` while selected, clickable while
/// [onPressed] is given.
class OcptSelectablePill extends StatelessWidget {
  /// The pill's label.
  final String label;

  /// Whether this pill is the selected one.
  final bool isSelected;

  /// Called when the pill is clicked, or null while it may not be used.
  final VoidCallback? onPressed;

  /// Class constructor
  const OcptSelectablePill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPressed = this.onPressed;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );

    if (onPressed == null) {
      return pill;
    }

    return InkWell(
      onTap: onPressed,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: pill,
    );
  }
}
