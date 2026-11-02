// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';

/// The dialog the schedule's whole-shoot PDF documents that take only the common options share: a
/// page format dropdown, the title page checkbox and the list of days to print, every day ticked
/// by default.
///
/// It builds the options the document runs with through [optionsOf] and pops them to whoever
/// showed the dialog, or pops nothing when the user cancelled.
class OcptScheduleDaysPdfExportDialog<T extends Object> extends StatefulWidget {
  /// The dialog's title.
  final String title;

  /// The page setup the schedule's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// Build the options the document runs with from what the user picked.
  final T Function({
    required OcptPageFormat format,
    required FountainPageMargins margins,
    required List<String> dayIds,
    required bool includeTitlePage,
  })
  optionsOf;

  /// Class constructor
  const OcptScheduleDaysPdfExportDialog({
    required this.title,
    required this.current,
    required this.days,
    required this.optionsOf,
    super.key,
  });

  /// Create the [_OcptScheduleDaysPdfExportDialogState] holding the state of the schedule days PDF
  /// export dialog.
  @override
  State<OcptScheduleDaysPdfExportDialog<T>> createState() =>
      _OcptScheduleDaysPdfExportDialogState<T>();
}

/// The state of [OcptScheduleDaysPdfExportDialog].
class _OcptScheduleDaysPdfExportDialogState<T extends Object>
    extends State<OcptScheduleDaysPdfExportDialog<T>> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The ids of the days currently ticked.
  late Set<String> _selectedDayIds;

  /// Whether the title page will be included in the exported document.
  bool _includeTitlePage = true;

  /// Seed the selection from the settings the dialog was opened with.
  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    _selectedDayIds = widget.days.map((day) => day.id).toSet();
  }

  /// Build the schedule days PDF export dialog as an [AlertDialog].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<OcptPageFormat>(
              initialValue: _selectedFormat,
              decoration: InputDecoration(labelText: tr.editorPageSetupPageSizeLabel),
              mouseCursor: ocpt_theme.ocptClickableCursor,
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

  /// Get the localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Pop the dialog returning the options [OcptScheduleDaysPdfExportDialog.optionsOf] builds, the
  /// selected days in [OcptScheduleDaysPdfExportDialog.days]' own order rather than selection
  /// order.
  ///
  /// The dialog is dismissed through the router manager (navigation only via the router
  /// manager), whose pop delivers the new options back to the caller that showed the dialog. It
  /// never disables its own export button while no day is ticked: an empty selection still
  /// produces a readable document, which the PDF service handles as a one-note page.
  void _submit() {
    final options = widget.optionsOf(
      format: _selectedFormat,
      margins: widget.current.margins,
      dayIds: [
        for (final day in widget.days)
          if (_selectedDayIds.contains(day.id)) day.id,
      ],
      includeTitlePage: _includeTitlePage,
    );
    globalGetIt().get<OcptRouterManager>().pop<T>(options);
  }
}
