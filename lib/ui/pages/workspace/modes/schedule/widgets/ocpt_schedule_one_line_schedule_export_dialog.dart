// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';

/// A dialog letting the user pick the one-off options a one-line schedule export runs with: the
/// page format, the title page, and which days the document prints.
///
/// Modelled on `OcptScheduleDayOutOfDaysExportDialog`, whose page-format dropdown, title-page
/// checkbox, day list and two buttons it shares the same reused strings for.
/// [OcptScheduleDaySelectionList] ticks every day by default here, as it does there: the common case
/// for a whole-shoot document is printing the whole shoot.
///
/// Use [show] to display it and get back the resulting [OcptOneLineScheduleExportOptions], or null
/// if the user cancelled.
class OcptScheduleOneLineScheduleExportDialog extends StatefulWidget {
  /// The page setup the schedule's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// Class constructor
  const OcptScheduleOneLineScheduleExportDialog({required this.current, required this.days, super.key});

  /// Shows the dialog and returns the [OcptOneLineScheduleExportOptions] the user applied, or null
  /// if they cancelled it.
  static Future<OcptOneLineScheduleExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required List<OcptShootingDay> days,
  }) => showDialog<OcptOneLineScheduleExportOptions>(
    context: context,
    builder: (context) => OcptScheduleOneLineScheduleExportDialog(current: current, days: days),
  );

  @override
  State<OcptScheduleOneLineScheduleExportDialog> createState() =>
      _OcptScheduleOneLineScheduleExportDialogState();
}

/// The state of [OcptScheduleOneLineScheduleExportDialog].
class _OcptScheduleOneLineScheduleExportDialogState
    extends State<OcptScheduleOneLineScheduleExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The ids of the days currently ticked.
  late Set<String> _selectedDayIds;

  /// Whether the title page will be included in the exported document.
  bool _includeTitlePage = true;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    _selectedDayIds = widget.days.map((day) => day.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.scheduleExportOneLineScheduleDialogTitle),
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeTitlePage,
              title: Text(tr.editorExportPdfTitlePageLabel),
              onChanged: (value) => setState(() => _includeTitlePage = value ?? true),
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
        FilledButton(onPressed: _submit, child: Text(tr.editorExportPdfExportAction)),
      ],
    );
  }

  /// The localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Pops the dialog returning the resulting [OcptOneLineScheduleExportOptions], the selected days
  /// in [OcptScheduleOneLineScheduleExportDialog.days]' own order rather than selection order.
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptScheduleOneLineScheduleExportDialog.show] caller. Like the *Day Out of Days*' own dialog,
  /// it never disables its own export button while no day is ticked: an empty selection still
  /// produces a readable document, which `OcptOneLineSchedulePdfService` already handles as a
  /// one-note page.
  void _submit() {
    final options = OcptOneLineScheduleExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      dayIds: [for (final day in widget.days) if (_selectedDayIds.contains(day.id)) day.id],
      includeTitlePage: _includeTitlePage,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptOneLineScheduleExportOptions>(options);
  }
}
