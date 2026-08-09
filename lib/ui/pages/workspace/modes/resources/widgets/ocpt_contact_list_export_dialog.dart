// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A dialog letting the user pick the one-off page format a contact list export runs with — this
/// document's own first options dialog, the resources mode having offered none until now.
///
/// Modelled on `OcptBreakdownSheetsExportDialog`, whose page-format wording it reuses: the two
/// dialogs ask the same question about the same thing, and wording it differently here would only
/// invite the reader to look for a difference that isn't there. Unlike that dialog, this one has no
/// content checkboxes of its own — a contact list has no optional section, only its two standing
/// ones.
///
/// Shows a page format dropdown, prefilled from [current] but never persisted: it only changes the
/// document being exported now. The margins of [current] are always carried through unchanged: this
/// dialog never lets the user edit them. Use [show] to display it and get back the resulting
/// [OcptContactListExportOptions], or null if the user cancelled.
class OcptContactListExportDialog extends StatefulWidget {
  /// The page setup the document is typeset with by default, used to pre-fill the format dropdown
  /// and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptContactListExportDialog({required this.current, super.key});

  /// Shows the dialog and returns the [OcptContactListExportOptions] the user applied, or null if
  /// they cancelled it.
  static Future<OcptContactListExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
  }) => showDialog<OcptContactListExportOptions>(
    context: context,
    builder: (context) => OcptContactListExportDialog(current: current),
  );

  @override
  State<OcptContactListExportDialog> createState() => _OcptContactListExportDialogState();
}

/// The state of [OcptContactListExportDialog].
class _OcptContactListExportDialogState extends State<OcptContactListExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.resourcesExportContactListDialogTitle),
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

  /// Pops the dialog returning the resulting [OcptContactListExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptContactListExportDialog.show] caller.
  void _submit() {
    final options = OcptContactListExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptContactListExportOptions>(options);
  }
}
