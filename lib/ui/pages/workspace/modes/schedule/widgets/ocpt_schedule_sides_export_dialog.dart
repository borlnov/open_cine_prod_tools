// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';

/// A dialog letting the user pick the one-off options a sides export runs with: the page format,
/// the one day printed, whether scene numbers are printed, and which presentation the booklet is
/// laid out in.
///
/// Modelled on `OcptScheduleOneLineScheduleExportDialog`, whose page-format dropdown and two
/// buttons it shares the same reused strings for. It picks **one** day out of a dropdown rather
/// than ticking several off `OcptScheduleDaySelectionList`, and that is the whole difference
/// between the two: a booklet of sides is one day's own paperwork, stapled and handed round on the
/// morning of that day, so a multi-day selection would produce several documents rather than a
/// longer one.
///
/// The dialog is only ever opened with at least one day (the mode's own `⋮` entry is disabled
/// otherwise), so its day dropdown always has something to show and its `Export` button is never
/// disabled.
///
/// Use [show] to display it and get back the resulting [OcptSidesExportOptions], or null if the
/// user cancelled.
class OcptScheduleSidesExportDialog extends StatefulWidget {
  /// The page setup the schedule's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by the day dropdown in the mode's own order.
  final List<OcptShootingDay> days;

  /// The day the mode currently has selected, pre-selected here — null, or naming a day no longer
  /// in [days], falls back to the first one.
  final String? selectedDayId;

  /// Class constructor
  const OcptScheduleSidesExportDialog({
    required this.current,
    required this.days,
    required this.selectedDayId,
    super.key,
  });

  /// Shows the dialog and returns the [OcptSidesExportOptions] the user applied, or null if they
  /// cancelled it.
  static Future<OcptSidesExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required List<OcptShootingDay> days,
    required String? selectedDayId,
  }) => showDialog<OcptSidesExportOptions>(
    context: context,
    builder: (context) =>
        OcptScheduleSidesExportDialog(current: current, days: days, selectedDayId: selectedDayId),
  );

  @override
  State<OcptScheduleSidesExportDialog> createState() => _OcptScheduleSidesExportDialogState();
}

/// The state of [OcptScheduleSidesExportDialog].
class _OcptScheduleSidesExportDialogState extends State<OcptScheduleSidesExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The id of the day currently selected in the dropdown.
  late String _selectedDayId;

  /// The presentation currently selected in the dropdown.
  OcptSidesPresentation _presentation = OcptSidesPresentation.scriptPages;

  /// Whether a scene heading prints its own scene number in both margins.
  bool _includeSceneNumbers = true;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    _selectedDayId = widget.days.any((day) => day.id == widget.selectedDayId)
        ? widget.selectedDayId!
        : widget.days.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).toString());

    return AlertDialog(
      title: Text(tr.scheduleExportSidesDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedDayId,
              decoration: InputDecoration(labelText: tr.scheduleExportSidesDayLabel),
              mouseCursor: ocptClickableCursor,
              items: [
                for (final day in widget.days)
                  DropdownMenuItem(
                    value: day.id,
                    child: Text(
                      "${ocptScheduleDayTagLabel(tr, day.kind, day.dayNumber)} · ${dateFormat.format(day.date)}",
                    ),
                  ),
              ],
              onChanged: (dayId) {
                if (dayId == null) {
                  return;
                }
                setState(() => _selectedDayId = dayId);
              },
            ),
            const SizedBox(height: 8),
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
            DropdownButtonFormField<OcptSidesPresentation>(
              initialValue: _presentation,
              decoration: InputDecoration(labelText: tr.scheduleExportSidesPresentationLabel),
              mouseCursor: ocptClickableCursor,
              items: [
                for (final presentation in OcptSidesPresentation.values)
                  DropdownMenuItem(
                    value: presentation,
                    child: Text(ocptSidesPresentationLabel(tr, presentation)),
                  ),
              ],
              onChanged: (presentation) {
                if (presentation == null) {
                  return;
                }
                setState(() => _presentation = presentation);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSceneNumbers,
              title: Text(tr.editorExportPdfSceneNumbersLabel),
              onChanged: (value) => setState(() => _includeSceneNumbers = value ?? true),
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

  /// Pops the dialog returning the resulting [OcptSidesExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptScheduleSidesExportDialog.show] caller.
  void _submit() {
    final options = OcptSidesExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      dayId: _selectedDayId,
      includeSceneNumbers: _includeSceneNumbers,
      presentation: _presentation,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptSidesExportOptions>(options);
  }
}
