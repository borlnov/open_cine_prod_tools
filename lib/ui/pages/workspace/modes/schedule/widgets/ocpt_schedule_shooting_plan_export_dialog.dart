// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';

/// A dialog letting the user pick the one-off options a shooting plan export runs with: the whole
/// shoot as a single PDF, the three summary grids and one detailed day agenda per selected day.
///
/// Modelled on `OcptScheduleCallSheetsExportDialog`, whose page-format dropdown, day list and two
/// buttons it shares the same reused strings for — the title page checkbox reuses
/// `OcptEditorExportPdfOptionsDialog`'s own wording too, the very same question the screenplay PDF
/// export already asks. [OcptScheduleDaySelectionList] ticks every day by default here, unlike the
/// call sheets dialog: the common case for a whole-shoot document is printing the whole shoot.
///
/// Use [show] to display it and get back the resulting [OcptShootingPlanExportOptions], or null if
/// the user cancelled.
class OcptScheduleShootingPlanExportDialog extends StatefulWidget {
  /// The page setup the three PDF exports are typeset with, used to pre-fill the format dropdown and
  /// to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// Class constructor
  const OcptScheduleShootingPlanExportDialog({required this.current, required this.days, super.key});

  /// Shows the dialog and returns the [OcptShootingPlanExportOptions] the user applied, or null if
  /// they cancelled it.
  static Future<OcptShootingPlanExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required List<OcptShootingDay> days,
  }) => showDialog<OcptShootingPlanExportOptions>(
    context: context,
    builder: (context) => OcptScheduleShootingPlanExportDialog(current: current, days: days),
  );

  @override
  State<OcptScheduleShootingPlanExportDialog> createState() =>
      _OcptScheduleShootingPlanExportDialogState();
}

/// The state of [OcptScheduleShootingPlanExportDialog].
class _OcptScheduleShootingPlanExportDialogState
    extends State<OcptScheduleShootingPlanExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The ids of the days currently ticked.
  late Set<String> _selectedDayIds;

  /// Whether the title page will be included in the exported document.
  bool _includeTitlePage = true;

  /// Whether the locations summary grid will be included.
  bool _includeLocationsGrid = true;

  /// Whether the sequences summary grid will be included.
  bool _includeSequencesGrid = true;

  /// Whether the crew and cast summary grid will be included.
  bool _includePeopleGrid = true;

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
      title: Text(tr.scheduleExportShootingPlanDialogTitle),
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeLocationsGrid,
              title: Text(tr.scheduleExportShootingPlanLocationsGridLabel),
              onChanged: (value) => setState(() => _includeLocationsGrid = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSequencesGrid,
              title: Text(tr.scheduleExportShootingPlanSequencesGridLabel),
              onChanged: (value) => setState(() => _includeSequencesGrid = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includePeopleGrid,
              title: Text(tr.scheduleExportShootingPlanPeopleGridLabel),
              onChanged: (value) => setState(() => _includePeopleGrid = value ?? true),
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

  /// Pops the dialog returning the resulting [OcptShootingPlanExportOptions], the selected days in
  /// [OcptScheduleShootingPlanExportDialog.days]' own order rather than selection order.
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptScheduleShootingPlanExportDialog.show] caller. Unlike its two siblings, this dialog never
  /// disables its own export button while no day is ticked: an empty selection still produces a
  /// readable document (the summary grids alone, or the title page alone), which
  /// `OcptShootingPlanPdfService` already handles as a one-note page.
  void _submit() {
    final options = OcptShootingPlanExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      dayIds: [for (final day in widget.days) if (_selectedDayIds.contains(day.id)) day.id],
      includeTitlePage: _includeTitlePage,
      includeLocationsGrid: _includeLocationsGrid,
      includeSequencesGrid: _includeSequencesGrid,
      includePeopleGrid: _includePeopleGrid,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptShootingPlanExportOptions>(options);
  }
}
