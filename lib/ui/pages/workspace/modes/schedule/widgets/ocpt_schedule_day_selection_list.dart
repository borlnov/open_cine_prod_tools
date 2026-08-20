// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';

/// The tallest the day list is ever drawn before it starts scrolling, in logical pixels — a forty-day
/// shoot still has to fit inside one dialog.
const double _ocptScheduleDaySelectionMaxHeight = 220;

/// A scrollable, checkbox list of days with "select all"/"select none" controls — shared by
/// `OcptScheduleCallSheetsExportDialog` and `OcptScheduleShootingPlanExportDialog`, the two export
/// dialogs that ask "which days to print" over what may be a forty-day shoot: offering the two bulk
/// controls rather than leaving the user to click forty boxes one at a time.
///
/// **Which days those are is the caller's**: the call sheets offer every day of the schedule, while
/// the four documents scoped to the shoot hand it `OcptScheduleState.shootingDays` alone. This
/// widget only draws what it is given, each row tagged through `ocptScheduleDayTagLabel`, so a
/// casting day reads `C1` wherever one is offered.
///
/// Purely presentational: [selectedDayIds] is owned by the caller, and every tick — a single row, or
/// one of the two bulk controls — reports the full next set through [onChanged] rather than a diff,
/// mirroring the idiom the rest of this app's checkbox lists already use.
///
/// The rows are a plain [Column] inside a [SingleChildScrollView] rather than a shrink-wrapped
/// [ListView], and deliberately so: an `AlertDialog` measures its content's **intrinsic** width, and
/// a shrink-wrapping viewport cannot report one — it throws at layout rather than merely looking
/// wrong. A shoot's worth of days is a handful of rows anyway, so laziness buys nothing here.
class OcptScheduleDaySelectionList extends StatelessWidget {
  /// Every day offered, in the order they are printed — the caller's own list; see the class doc
  /// comment for which days each dialog hands over.
  final List<OcptShootingDay> days;

  /// The ids of the days currently ticked.
  final Set<String> selectedDayIds;

  /// Called with the full next set of ticked day ids, whatever triggered the change.
  final ValueChanged<Set<String>> onChanged;

  /// Class constructor
  const OcptScheduleDaySelectionList({
    required this.days,
    required this.selectedDayIds,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMMd(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.scheduleExportDaysToPrintLabel, style: Theme.of(context).textTheme.labelLarge),
        Row(
          children: [
            TextButton(
              onPressed: () => onChanged(days.map((day) => day.id).toSet()),
              child: Text(tr.scheduleExportSelectAllAction),
            ),
            TextButton(
              onPressed: () => onChanged(const {}),
              child: Text(tr.scheduleExportSelectNoneAction),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _ocptScheduleDaySelectionMaxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final day in days)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    mouseCursor: ocptClickableCursor,
                    value: selectedDayIds.contains(day.id),
                    title: Text(
                      "${ocptScheduleDayTagLabel(tr, day.kind, day.dayNumber)} · "
                      "${dateFormat.format(day.date)}",
                    ),
                    onChanged: (checked) {
                      final next = Set<String>.of(selectedDayIds);
                      if (checked ?? false) {
                        next.add(day.id);
                      } else {
                        next.remove(day.id);
                      }
                      onChanged(next);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
