// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_export_options.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';

/// A dialog letting the user pick the one-off options a shooting plan **workbook** export runs
/// with: which days it covers, and nothing else.
///
/// A small dedicated dialog rather than a reuse of `OcptScheduleShootingPlanExportDialog`: that one
/// also asks for a page format and four section toggles, neither of which means anything to a
/// spreadsheet (§5 of the export panel's own design — a sheet costs nothing and is hidden in one
/// click, and page geometry is the printer's business). [OcptScheduleDaySelectionList] ticks every
/// day by default here, as its PDF sibling does: the common case for a whole-shoot document is
/// printing the whole shoot.
///
/// Use [show] to display it and get back the resulting [OcptShootingPlanXlsxExportOptions], or null
/// if the user cancelled.
class OcptScheduleShootingPlanXlsxExportDialog extends StatefulWidget {
  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// Class constructor
  const OcptScheduleShootingPlanXlsxExportDialog({required this.days, super.key});

  /// Shows the dialog and returns the [OcptShootingPlanXlsxExportOptions] the user applied, or null
  /// if they cancelled it.
  static Future<OcptShootingPlanXlsxExportOptions?> show(
    BuildContext context, {
    required List<OcptShootingDay> days,
  }) => showDialog<OcptShootingPlanXlsxExportOptions>(
    context: context,
    builder: (context) => OcptScheduleShootingPlanXlsxExportDialog(days: days),
  );

  @override
  State<OcptScheduleShootingPlanXlsxExportDialog> createState() =>
      _OcptScheduleShootingPlanXlsxExportDialogState();
}

/// The state of [OcptScheduleShootingPlanXlsxExportDialog].
class _OcptScheduleShootingPlanXlsxExportDialogState
    extends State<OcptScheduleShootingPlanXlsxExportDialog> {
  /// The ids of the days currently ticked.
  late Set<String> _selectedDayIds;

  @override
  void initState() {
    super.initState();
    _selectedDayIds = widget.days.map((day) => day.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.scheduleExportShootingPlanXlsxDialogTitle),
      content: SingleChildScrollView(
        child: OcptScheduleDaySelectionList(
          days: widget.days,
          selectedDayIds: _selectedDayIds,
          onChanged: (next) => setState(() => _selectedDayIds = next),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.editorPageSetupCancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(tr.editorExportPdfExportAction)),
      ],
    );
  }

  /// Pops the dialog returning the resulting [OcptShootingPlanXlsxExportOptions], the selected days
  /// in [OcptScheduleShootingPlanXlsxExportDialog.days]' own order rather than selection order —
  /// mirrors `OcptScheduleShootingPlanExportDialog._submit`.
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager). Never disables its own export button while no day is ticked: an empty selection
  /// still produces a readable workbook (every sheet left with its own header rows alone), which
  /// `OcptShootingPlanXlsxExportService` already handles.
  void _submit() {
    final options = OcptShootingPlanXlsxExportOptions(
      dayIds: [for (final day in widget.days) if (_selectedDayIds.contains(day.id)) day.id],
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptShootingPlanXlsxExportOptions>(options);
  }
}
