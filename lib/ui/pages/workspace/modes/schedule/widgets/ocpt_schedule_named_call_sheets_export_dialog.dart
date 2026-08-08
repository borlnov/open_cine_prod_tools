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
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

/// The tallest the convocation list is ever drawn before it starts scrolling, in logical pixels.
const double _ocptScheduleNamedCallSheetsMaxHeight = 260;

/// A dialog letting the user pick the one-off options a **named** call sheets export runs with: one
/// PDF per convoked person or uncast role of [day], written into a folder.
///
/// Modelled on `OcptScheduleCallSheetsExportDialog`, whose page-format dropdown and two buttons it
/// shares the same reused strings for (in turn reused from `OcptBreakdownSheetsExportDialog`). The
/// day itself is **not chosen here** — a named export is always the mode's own selected day — so the
/// dialog's own content is the day's whole call (ADR 0018), every entry ticked by default, since the
/// common case is sending every named sheet to whoever is convoked. An uncast role is listed like
/// any other convocation and named by its role, with a plain hint that such a sheet has nobody to
/// send it to yet.
///
/// Use [show] to display it and get back the resulting [OcptCallSheetExportOptions], or null if the
/// user cancelled.
class OcptScheduleNamedCallSheetsExportDialog extends StatefulWidget {
  /// The page setup the three PDF exports are typeset with, used to pre-fill the format dropdown and
  /// to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// The day this export prints, fixed for the whole dialog.
  final OcptShootingDay day;

  /// The day's own whole call (ADR 0018) — `OcptScheduleState.convocationsOfDay(day.id)`.
  final List<OcptDayConvocation> convocations;

  /// The whole address book, keyed by id — resolves a convocation's own display name.
  final Map<String, OcptPerson> personById;

  /// The whole cast, keyed by id — resolves an uncast convocation's own role name.
  final Map<String, OcptRole> roleById;

  /// Class constructor
  const OcptScheduleNamedCallSheetsExportDialog({
    required this.current,
    required this.day,
    required this.convocations,
    required this.personById,
    required this.roleById,
    super.key,
  });

  /// Shows the dialog and returns the [OcptCallSheetExportOptions] the user applied, or null if they
  /// cancelled it.
  static Future<OcptCallSheetExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required OcptShootingDay day,
    required List<OcptDayConvocation> convocations,
    required Map<String, OcptPerson> personById,
    required Map<String, OcptRole> roleById,
  }) => showDialog<OcptCallSheetExportOptions>(
    context: context,
    builder: (context) => OcptScheduleNamedCallSheetsExportDialog(
      current: current,
      day: day,
      convocations: convocations,
      personById: personById,
      roleById: roleById,
    ),
  );

  @override
  State<OcptScheduleNamedCallSheetsExportDialog> createState() =>
      _OcptScheduleNamedCallSheetsExportDialogState();
}

/// The state of [OcptScheduleNamedCallSheetsExportDialog].
class _OcptScheduleNamedCallSheetsExportDialogState
    extends State<OcptScheduleNamedCallSheetsExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The convocation keys currently ticked — a person's own id, or an uncast role's, exactly as
  /// `OcptDayConvocation.personId`/`.roleId` discriminate one.
  late Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    _selectedKeys = {for (final convocation in widget.convocations) _keyOf(convocation)};
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.scheduleExportNamedCallSheetsDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ocptScheduleDayTagLabel(tr, widget.day.dayNumber),
              style: Theme.of(context).textTheme.labelMedium,
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
            Text(tr.scheduleExportRecipientsSectionTitle, style: Theme.of(context).textTheme.labelLarge),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(
                    () => _selectedKeys = {
                      for (final convocation in widget.convocations) _keyOf(convocation),
                    },
                  ),
                  child: Text(tr.scheduleExportSelectAllAction),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedKeys = const {}),
                  child: Text(tr.scheduleExportSelectNoneAction),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _ocptScheduleNamedCallSheetsMaxHeight),
              // A plain column inside a scroll view rather than a shrink-wrapped `ListView`: an
              // `AlertDialog` measures its content's intrinsic width, which a shrink-wrapping
              // viewport cannot report — it throws at layout. See `OcptScheduleDaySelectionList`,
              // which says the same thing about its own rows.
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final convocation in widget.convocations)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        mouseCursor: ocptClickableCursor,
                        value: _selectedKeys.contains(_keyOf(convocation)),
                        title: Text(
                          ocptScheduleConvocationTitle(
                            tr,
                            convocation,
                            widget.personById,
                            widget.roleById,
                          ),
                        ),
                        subtitle: convocation.personId == null
                            ? Text(tr.scheduleExportNamedCallSheetsUncastRoleHint)
                            : null,
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _selectedKeys.add(_keyOf(convocation));
                          } else {
                            _selectedKeys.remove(_keyOf(convocation));
                          }
                        }),
                      ),
                  ],
                ),
              ),
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
          onPressed: _selectedKeys.isEmpty ? null : _submit,
          child: Text(tr.editorExportPdfExportAction),
        ),
      ],
    );
  }

  /// [convocation]'s own selection key — see [_selectedKeys]' own doc comment.
  String _keyOf(OcptDayConvocation convocation) => (convocation.personId ?? convocation.roleId)!;

  /// The localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Pops the dialog returning the resulting [OcptCallSheetExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptScheduleNamedCallSheetsExportDialog.show] caller.
  void _submit() {
    final options = OcptCallSheetExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      dayIds: [widget.day.id],
      selectedConvocationKeys: _selectedKeys,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptCallSheetExportOptions>(options);
  }
}
