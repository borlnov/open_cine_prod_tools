// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';

/// A dialog letting the user pick the one-off options a **general** call sheets export runs with:
/// one PDF per selected day, written into a folder.
///
/// Modelled on `OcptBreakdownSheetsExportDialog`, whose strings it reuses for everything the two
/// dialogs ask the same question about (the page size, the two buttons): wording the very same
/// option differently in the two places would only invite the reader to look for a difference that
/// isn't there. [OcptScheduleDaySelectionList] is this dialog's own — the day currently selected in
/// the mode is ticked by default, the rest left for the user to add.
///
/// Shows a page format dropdown (prefilled from [current], but never persisted: it only changes the
/// documents being exported now) and the day list. The margins of [current] are always carried
/// through unchanged: this dialog never lets the user edit them. Use [show] to display it and get
/// back the resulting [OcptCallSheetExportOptions], or null if the user cancelled.
class OcptScheduleCallSheetsExportDialog extends StatefulWidget {
  /// The page setup the three PDF exports are typeset with, used to pre-fill the format dropdown and
  /// to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// The id of the day currently selected in the mode, ticked by default — or null while none is.
  final String? selectedDayId;

  /// Class constructor
  const OcptScheduleCallSheetsExportDialog({
    required this.current,
    required this.days,
    required this.selectedDayId,
    super.key,
  });

  /// Shows the dialog and returns the [OcptCallSheetExportOptions] the user applied, or null if they
  /// cancelled it.
  static Future<OcptCallSheetExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required List<OcptShootingDay> days,
    required String? selectedDayId,
  }) => showDialog<OcptCallSheetExportOptions>(
    context: context,
    builder: (context) => OcptScheduleCallSheetsExportDialog(
      current: current,
      days: days,
      selectedDayId: selectedDayId,
    ),
  );

  @override
  State<OcptScheduleCallSheetsExportDialog> createState() =>
      _OcptScheduleCallSheetsExportDialogState();
}

/// The state of [OcptScheduleCallSheetsExportDialog].
class _OcptScheduleCallSheetsExportDialogState extends State<OcptScheduleCallSheetsExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The ids of the days currently ticked.
  late Set<String> _selectedDayIds;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    _selectedDayIds = {if (widget.selectedDayId != null) widget.selectedDayId!};
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.scheduleExportCallSheetsDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<OcptPageFormat>(
              initialValue: _selectedFormat,
              decoration: InputDecoration(labelText: tr.editorPageSetupPageSizeLabel),
              mouseCursor: ocptClickableCursor,
              items: [
                for (final format in OcptPageFormat.values)
                  DropdownMenuItem(value: format, child: Text(_formatLabel(tr, format))),
              ],
              onChanged: (format) {
                if (format == null) {
                  return;
                }
                setState(() => _selectedFormat = format);
              },
            ),
            const SizedBox(height: 8),
            OcptScheduleDaySelectionList(
              days: widget.days,
              selectedDayIds: _selectedDayIds,
              onChanged: (next) => setState(() => _selectedDayIds = next),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.editorPageSetupCancelAction),
        ),
        FilledButton(
          onPressed: _selectedDayIds.isEmpty ? null : _submit,
          child: Text(tr.editorExportPdfExportAction),
        ),
      ],
    );
  }

  /// The localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Pops the dialog returning the resulting [OcptCallSheetExportOptions], the selected days in
  /// [OcptScheduleCallSheetsExportDialog.days]' own order rather than selection order.
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptScheduleCallSheetsExportDialog.show] caller.
  void _submit() {
    final options = OcptCallSheetExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      dayIds: [for (final day in widget.days) if (_selectedDayIds.contains(day.id)) day.id],
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptCallSheetExportOptions>(options);
  }
}
