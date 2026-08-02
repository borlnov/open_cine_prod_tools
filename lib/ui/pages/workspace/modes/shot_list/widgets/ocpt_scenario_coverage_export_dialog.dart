// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A dialog letting the user pick the one-off options a scenario coverage export runs with.
///
/// Modelled on `OcptEditorExportPdfOptionsDialog`, which it deliberately reuses the strings of for
/// everything the two dialogs ask the same question about (the page size, the scene numbers, the
/// title page, the two buttons): the coverage document prints the very same screenplay, so wording
/// the very same option differently in the two places would only invite the reader to look for a
/// difference that isn't there. The two toggles below them are this export's own — one per appendix
/// page.
///
/// Shows a page format dropdown (prefilled from [current], but never persisted: it only changes the
/// document being exported now) and four checkboxes, all defaulting on. The margins of [current] are
/// always carried through unchanged: this dialog never lets the user edit them. Use [show] to
/// display it and get back the resulting [OcptScenarioCoverageExportOptions], or null if the user
/// cancelled.
class OcptScenarioCoverageExportDialog extends StatefulWidget {
  /// The page setup the screenplay is typeset with, used to pre-fill the format dropdown and to
  /// supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptScenarioCoverageExportDialog({required this.current, super.key});

  /// Shows the dialog and returns the [OcptScenarioCoverageExportOptions] the user applied, or null
  /// if they cancelled it.
  static Future<OcptScenarioCoverageExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
  }) => showDialog<OcptScenarioCoverageExportOptions>(
    context: context,
    builder: (context) => OcptScenarioCoverageExportDialog(current: current),
  );

  @override
  State<OcptScenarioCoverageExportDialog> createState() => _OcptScenarioCoverageExportDialogState();
}

/// The state of [OcptScenarioCoverageExportDialog].
class _OcptScenarioCoverageExportDialogState extends State<OcptScenarioCoverageExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// Whether scene numbers will be included in the exported document.
  bool _includeSceneNumbers = true;

  /// Whether a title page will be included in the exported document.
  bool _includeTitlePage = true;

  /// Whether the shot legend page will be included in the exported document.
  bool _includeLegendPage = true;

  /// Whether the coverage summary page will be included in the exported document.
  bool _includeSummaryPage = true;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.shotListExportCoverageDialogTitle),
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
              value: _includeSceneNumbers,
              title: Text(tr.editorExportPdfSceneNumbersLabel),
              onChanged: (value) => setState(() => _includeSceneNumbers = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeTitlePage,
              title: Text(tr.editorExportPdfTitlePageLabel),
              onChanged: (value) => setState(() => _includeTitlePage = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeLegendPage,
              title: Text(tr.shotListExportCoverageLegendLabel),
              onChanged: (value) => setState(() => _includeLegendPage = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSummaryPage,
              title: Text(tr.shotListExportCoverageSummaryLabel),
              onChanged: (value) => setState(() => _includeSummaryPage = value ?? true),
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

  /// Pops the dialog returning the resulting [OcptScenarioCoverageExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptScenarioCoverageExportDialog.show] caller.
  void _submit() {
    final options = OcptScenarioCoverageExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      includeSceneNumbers: _includeSceneNumbers,
      includeTitlePage: _includeTitlePage,
      includeLegendPage: _includeLegendPage,
      includeSummaryPage: _includeSummaryPage,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptScenarioCoverageExportOptions>(options);
  }
}
