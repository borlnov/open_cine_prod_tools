// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_days_pdf_export_dialog.dart';

/// A dialog letting the user pick the one-off options a one-line schedule export runs with: the
/// page format, the title page, and which days the document prints.
///
/// Modelled on `OcptScheduleDayOutOfDaysExportDialog`, whose page-format dropdown, title-page
/// checkbox, day list and two buttons it shares the same reused strings for.
/// [OcptScheduleDaySelectionList] ticks every day by default here, as it does there: the common
/// case for a whole-shoot document is printing the whole shoot.
///
/// Use [show] to display it and get back the resulting [OcptOneLineScheduleExportOptions], or null
/// if the user cancelled.
class OcptScheduleOneLineScheduleExportDialog extends StatelessWidget {
  /// The page setup the schedule's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// Class constructor
  const OcptScheduleOneLineScheduleExportDialog({
    required this.current,
    required this.days,
    super.key,
  });

  /// Build the dialog as an [OcptScheduleDaysPdfExportDialog] building a
  /// [OcptOneLineScheduleExportOptions].
  @override
  Widget build(BuildContext context) =>
      OcptScheduleDaysPdfExportDialog<OcptOneLineScheduleExportOptions>(
        title: Tr.of(context).scheduleExportOneLineScheduleDialogTitle,
        current: current,
        days: days,
        optionsOf: OcptOneLineScheduleExportOptions.new,
      );

  /// Show the dialog and return the [OcptOneLineScheduleExportOptions]
  /// the user applied, or null if they cancelled it.
  static Future<OcptOneLineScheduleExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required List<OcptShootingDay> days,
  }) => showDialog<OcptOneLineScheduleExportOptions>(
    context: context,
    builder: (context) => OcptScheduleOneLineScheduleExportDialog(current: current, days: days),
  );
}
