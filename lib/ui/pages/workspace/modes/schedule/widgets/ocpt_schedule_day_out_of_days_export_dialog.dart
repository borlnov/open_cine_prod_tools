// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_days_pdf_export_dialog.dart';

/// A dialog letting the user pick the one-off options a *Day Out of Days* export runs with: the
/// page format, the title page, and which days the table crosses.
///
/// Modelled on `OcptScheduleShootingPlanExportDialog`, whose page-format dropdown, title-page
/// checkbox, day list and two buttons it shares the same reused strings for.
/// [OcptScheduleDaySelectionList] ticks every day by default here, as it does there: the common
/// case for a whole-shoot document is printing the whole shoot, and the days ticked are exactly the
/// range every `SW`/`WF` in the table is read against.
///
/// Use [show] to display it and get back the resulting [OcptDayOutOfDaysExportOptions], or null if
/// the user cancelled.
class OcptScheduleDayOutOfDaysExportDialog extends StatelessWidget {
  /// The page setup the schedule's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// Class constructor
  const OcptScheduleDayOutOfDaysExportDialog({
    required this.current,
    required this.days,
    super.key,
  });

  /// Build the dialog as an [OcptScheduleDaysPdfExportDialog] building a
  /// [OcptDayOutOfDaysExportOptions].
  @override
  Widget build(BuildContext context) =>
      OcptScheduleDaysPdfExportDialog<OcptDayOutOfDaysExportOptions>(
        title: Tr.of(context).scheduleExportDayOutOfDaysDialogTitle,
        current: current,
        days: days,
        optionsOf: OcptDayOutOfDaysExportOptions.new,
      );

  /// Show the dialog and return the [OcptDayOutOfDaysExportOptions] the user applied, or null if they cancelled it.
  static Future<OcptDayOutOfDaysExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required List<OcptShootingDay> days,
  }) => showDialog<OcptDayOutOfDaysExportOptions>(
    context: context,
    builder: (context) => OcptScheduleDayOutOfDaysExportDialog(current: current, days: days),
  );
}
