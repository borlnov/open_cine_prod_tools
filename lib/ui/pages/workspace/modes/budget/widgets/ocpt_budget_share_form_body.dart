// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_percent_permille.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';

/// The whole of [OcptBudgetShareDialog]'s own form, embeddable outside a dialog — the capture
/// wizard draws this same body under its own step counter, rather than an `AlertDialog`'s
/// `content`.
///
/// **`Label` is the dialog's own only required field.** `Person`, `Share` and `Reinvest` all carry
/// a sensible default the moment the dialog opens (no person, 0 %, 0 %), so there is no second
/// field a fresh share could be missing.
///
/// **`Person` is a picker offering [people] alongside its own explicit "no person" choice** —
/// `OcptBudgetShare.personId`'s own doc comment: a role such as "Production" is a real participant
/// naming no one person, so null is the ordinary, legitimate answer here, not an unfinished pick.
///
/// **`Share` and `Reinvest` are typed as percentages and stored as per mille**, through
/// [ocptPercentPermilleOf]/[ocptPermillePercentTextOf]
/// (`lib/models/rules/ocpt_percent_permille.dart`) — see that file's own doc comment for why
/// neither `ocptCostCentsOf` nor `ocptVatRateBasisPointsOf`/`ocptMileageRateMilliCentsOf` fit this
/// one scale.
///
/// **The sum of every live share's own `Share` is never checked here.** `OcptBudgetSharesTable`'s
/// own doc comment and `OcptBudgetSharing`'s own class doc comment both argue why the app states
/// the mismatch rather than refusing the write — this body is not the place that argument would
/// live even if it did check, since a single share's own field can never tell whether the *others*
/// still sum correctly.
///
/// **The host owns the submit gesture.** [formKey] is put on this body's own [Form], and
/// [onDraftChanged] fires with the fields this body would submit right now — or null while
/// `_shareController`'s or `_reinvestController`'s own percentage does not parse, the one way this
/// body can be unreadable — every time a field changes, `initState` included so a host that never
/// touches a pre-filled edit still has a draft to submit. The host validates [formKey] and uses the
/// last reported draft on its own `Save`; this body never pops anything itself.
class OcptBudgetShareFormBody extends StatefulWidget {
  /// The share being edited, or null while creating a new one.
  final OcptBudgetShare? existing;

  /// Every live person of the project's address book, offered by the `Person` picker alongside its
  /// own explicit "no person" choice.
  final List<OcptPerson> people;

  /// The form this body's own [Form] validates against — the host's to create and to validate.
  final GlobalKey<FormState> formKey;

  /// Called with the fields this body would submit right now, or null while it cannot be read at
  /// all — see the class doc comment.
  final ValueChanged<OcptBudgetShareFormFields?> onDraftChanged;

  /// Class constructor
  const OcptBudgetShareFormBody({
    super.key,
    required this.existing,
    required this.people,
    required this.formKey,
    required this.onDraftChanged,
  });

  /// Create the [_OcptBudgetShareFormBodyState] holding the state of the budget share form body.
  @override
  State<OcptBudgetShareFormBody> createState() => _OcptBudgetShareFormBodyState();
}

/// The state of [OcptBudgetShareFormBody].
class _OcptBudgetShareFormBodyState extends State<OcptBudgetShareFormBody> {
  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the share field.
  late final TextEditingController _shareController;

  /// The controller of the reinvest field.
  late final TextEditingController _reinvestController;

  /// The controller of the notes field.
  late final TextEditingController _notesController;

  /// The person currently picked, or null for "no person" — the normal case, see the class doc
  /// comment.
  String? _personId;

  /// The fields this body would submit right now, or null while `_shareController`'s or
  /// `_reinvestController`'s own percentage does not parse.
  OcptBudgetShareFormFields? get _currentDraft {
    final sharePermille = ocptPercentPermilleOf(_shareController.text);
    final reinvestPermille = ocptPercentPermilleOf(_reinvestController.text);
    if (sharePermille == null || reinvestPermille == null) {
      return null;
    }

    return OcptBudgetShareFormFields(
      personId: _personId,
      label: _labelController.text.trim(),
      sharePermille: sharePermille,
      reinvestPermille: reinvestPermille,
      notes: _notesController.text.trim(),
    );
  }

  /// Fill the fields from the existing share, and send the first draft after the first frame.
  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _personId = existing?.personId;

    _labelController = TextEditingController(text: existing?.label ?? "")..addListener(_report);
    _shareController = TextEditingController(
      text: ocptPermillePercentTextOf(existing?.sharePermille ?? 0),
    )..addListener(_report);
    _reinvestController = TextEditingController(
      text: ocptPermillePercentTextOf(existing?.reinvestPermille ?? 0),
    )..addListener(_report);
    _notesController = TextEditingController(text: existing?.notes ?? "")..addListener(_report);

    // The host's own `Save` may be reached before any field is touched — an edit left exactly as
    // it opened — so the very first draft has to travel without waiting on a keystroke.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _report();
      }
    });
  }

  /// Build the budget share form body as a [Form].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _labelController,
              autofocus: true,
              decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
              validator: (value) =>
                  (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _personId,
              decoration: InputDecoration(labelText: tr.budgetShareDialogPersonFieldLabel),
              items: [
                DropdownMenuItem(child: Text(tr.budgetShareDialogNoPersonLabel)),
                for (final person in widget.people)
                  DropdownMenuItem(value: person.id, child: Text(person.displayName)),
              ],
              onChanged: (value) {
                setState(() => _personId = value);
                _report();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shareController,
              decoration: InputDecoration(
                labelText: tr.budgetShareDialogShareFieldLabel,
                suffixText: tr.budgetLineVatRateSuffix,
              ),
              validator: (value) => ocptPercentPermilleOf(value ?? "") == null
                  ? tr.budgetShareDialogPercentInvalidError
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reinvestController,
              decoration: InputDecoration(
                labelText: tr.budgetShareDialogReinvestFieldLabel,
                suffixText: tr.budgetLineVatRateSuffix,
              ),
              validator: (value) => ocptPercentPermilleOf(value ?? "") == null
                  ? tr.budgetShareDialogPercentInvalidError
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: tr.budgetLineNotesFieldLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// Reports [_currentDraft] to the host — every controller listener and every picker's own
  /// `onChanged` call this after applying its own change.
  void _report() => widget.onDraftChanged(_currentDraft);

  /// Dispose [_labelController], [_shareController], [_reinvestController] and [_notesController].
  @override
  void dispose() {
    _labelController.dispose();
    _shareController.dispose();
    _reinvestController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
