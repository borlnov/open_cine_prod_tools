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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_selection_list.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

/// The tallest the convocation list is ever drawn before it starts scrolling, in logical pixels.
const double _ocptScheduleNamedCallSheetsMaxHeight = 260;

/// A dialog letting the user pick the one-off options a **named** call sheets export runs with: one
/// PDF per (ticked day × ticked recipient), written into a folder.
///
/// Modelled on `OcptScheduleCallSheetsExportDialog`, whose page-format dropdown, its two buttons and
/// its own [OcptScheduleDaySelectionList] this dialog reuses outright (in turn reused from
/// `OcptBreakdownSheetsExportDialog` for the format and the buttons). Unlike that dialog, ticking a
/// day here does more than choose what gets printed: the recipient list itself is the **union** of
/// the ticked days' own convocations, deduplicated by `OcptDayConvocation.selectionKey` — a person
/// convoked on two of the ticked days appears once in the list, and ticking or unticking them there
/// prints (or withholds) their sheet for every one of those days. Changing which days are ticked
/// recomputes that union and carries the tick state over rather than resetting it: a recipient still
/// in the union keeps whatever the user set for them, one newly appearing is ticked (the dialog's
/// standing default is "everybody"), and one that has left the union is simply dropped — see the
/// state's own `_onDaysChanged`. An uncast role is listed like any other convocation and named by
/// its role, with a plain hint that such a sheet has nobody to send it to yet.
///
/// **A candidate is a recipient like anybody else**, named by their candidacy — who is coming, and
/// the part they are coming to be seen for — since two candidacies of one person are two
/// convocations, and a name alone could not tell them apart. Only a **guest** is absent, carrying no
/// `selectionKey` at all: `OcptScheduleModeContent` filters the list on that, so this dialog needs
/// no rule of its own about who may be written to.
///
/// Use [show] to display it and get back the resulting [OcptCallSheetExportOptions], or null if the
/// user cancelled.
class OcptScheduleNamedCallSheetsExportDialog extends StatefulWidget {
  /// The page setup the three PDF exports are typeset with, used to pre-fill the format dropdown and
  /// to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Every live shooting day, offered by [OcptScheduleDaySelectionList].
  final List<OcptShootingDay> days;

  /// The id of the day currently selected in the mode, ticked by default — or null while none is.
  final String? selectedDayId;

  /// A day's own whole call (ADR 0018), read on demand rather than handed in as a pre-computed map:
  /// the ticked days change while the dialog is open, and joining a day's convocations is a real
  /// walk — the same "handed as a function reference" idiom
  /// `OcptSchedulePlanSnapshot.timelinesOfDay` already uses with the three agendas, for the same
  /// reason: recomputing it eagerly for every day the mode holds would do work for days the dialog
  /// may never tick.
  final List<OcptDayConvocation> Function(String dayId) recipientsOfDay;

  /// The whole address book, keyed by id — resolves a convocation's own display name.
  final Map<String, OcptPerson> personById;

  /// The whole cast, keyed by id — resolves an uncast convocation's own role name, and the part a
  /// candidate is coming to be seen for.
  final Map<String, OcptRole> roleById;


  /// Class constructor
  const OcptScheduleNamedCallSheetsExportDialog({
    required this.current,
    required this.days,
    required this.selectedDayId,
    required this.recipientsOfDay,
    required this.personById,
    required this.roleById,
    super.key,
  });

  /// Shows the dialog and returns the [OcptCallSheetExportOptions] the user applied, or null if they
  /// cancelled it.
  static Future<OcptCallSheetExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required List<OcptShootingDay> days,
    required String? selectedDayId,
    required List<OcptDayConvocation> Function(String dayId) recipientsOfDay,
    required Map<String, OcptPerson> personById,
    required Map<String, OcptRole> roleById,
  }) => showDialog<OcptCallSheetExportOptions>(
    context: context,
    builder: (context) => OcptScheduleNamedCallSheetsExportDialog(
      current: current,
      days: days,
      selectedDayId: selectedDayId,
      recipientsOfDay: recipientsOfDay,
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

  /// The ids of the days currently ticked.
  late Set<String> _selectedDayIds;

  /// The union of [_selectedDayIds]' own convocations, deduplicated by [_keyOf] — the list the
  /// checkboxes below are built from. Recomputed by [_onDaysChanged] whenever the ticked days change.
  late List<OcptDayConvocation> _recipients;

  /// The convocation keys currently ticked — `OcptDayConvocation.selectionKey`, the one place that
  /// reading is written.
  late Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    _selectedDayIds = {if (widget.selectedDayId != null) widget.selectedDayId!};
    _recipients = _unionOf(_selectedDayIds);
    _selectedKeys = {for (final convocation in _recipients) _keyOf(convocation)};
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
              onChanged: _onDaysChanged,
            ),
            const SizedBox(height: 8),
            Text(tr.scheduleExportRecipientsSectionTitle, style: Theme.of(context).textTheme.labelLarge),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(
                    () => _selectedKeys = {
                      for (final convocation in _recipients) _keyOf(convocation),
                    },
                  ),
                  child: Text(tr.scheduleExportSelectAllAction),
                ),
                TextButton(
                  // A growable set rather than `const {}`: the checkboxes below add to and remove
                  // from this very set in place, and a const one throws the moment the user ticks
                  // somebody back on after clearing the list.
                  onPressed: () => setState(() => _selectedKeys = <String>{}),
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
                    for (final convocation in _recipients)
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
                        // The hint belongs to an **uncast role** alone, which is the one recipient
                        // this app can name nobody for. A candidate names a person as squarely as a
                        // crew member does, through their candidacy, and reading `personId == null`
                        // here would have told an assistant director that somebody they are about
                        // to see has nobody to send the sheet to.
                        subtitle: convocation.roleId != null
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
          onPressed: _selectedDayIds.isEmpty || _selectedKeys.isEmpty ? null : _submit,
          child: Text(tr.editorExportPdfExportAction),
        ),
      ],
    );
  }

  /// The union of [dayIds]' own convocations (via [OcptScheduleNamedCallSheetsExportDialog.days]'
  /// own order, then each day's own convocation order), deduplicated by [_keyOf]: a person convoked
  /// on more than one of [dayIds] contributes one entry, its first.
  List<OcptDayConvocation> _unionOf(Set<String> dayIds) {
    final seenKeys = <String>{};
    return [
      for (final day in widget.days)
        if (dayIds.contains(day.id))
          for (final convocation in widget.recipientsOfDay(day.id))
            if (seenKeys.add(_keyOf(convocation))) convocation,
    ];
  }

  /// Recomputes [_recipients] against [nextDayIds] and carries the tick state over: a key still in
  /// the recomputed union keeps whatever [_selectedKeys] already says about it, a key the previous
  /// union didn't have is ticked (this dialog's standing default is "everybody"), and a key the new
  /// union no longer has is dropped — simply by not being iterated below, [_selectedKeys] holding
  /// ticked keys alone.
  void _onDaysChanged(Set<String> nextDayIds) {
    final previousKeys = _recipients.map(_keyOf).toSet();
    final nextRecipients = _unionOf(nextDayIds);
    final nextKeys = nextRecipients.map(_keyOf).toSet();

    setState(() {
      _selectedDayIds = nextDayIds;
      _recipients = nextRecipients;
      _selectedKeys = {
        for (final key in nextKeys)
          if (!previousKeys.contains(key) || _selectedKeys.contains(key)) key,
      };
    });
  }

  /// [convocation]'s own selection key — see [_selectedKeys]' own doc comment.
  ///
  /// Non-null for every convocation this dialog is ever handed: a guest is the one kind that carries
  /// none, and [OcptScheduleNamedCallSheetsExportDialog.recipientsOfDay] filters those out before
  /// the list ever reaches here.
  String _keyOf(OcptDayConvocation convocation) => convocation.selectionKey!;

  /// The localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Pops the dialog returning the resulting [OcptCallSheetExportOptions], the selected days in
  /// [OcptScheduleNamedCallSheetsExportDialog.days]' own order rather than selection order — mirrors
  /// `OcptScheduleCallSheetsExportDialog._submit`.
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptScheduleNamedCallSheetsExportDialog.show] caller.
  void _submit() {
    final options = OcptCallSheetExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      dayIds: [for (final day in widget.days) if (_selectedDayIds.contains(day.id)) day.id],
      selectedConvocationKeys: _selectedKeys,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptCallSheetExportOptions>(options);
  }
}
