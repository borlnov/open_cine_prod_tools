// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_form_body.dart';

/// The dialog that both **creates and edits** a commitment — one shape for both, mirroring
/// `OcptBudgetEntryDialog`'s own structure exactly, [show] and all: a [Form], an `AlertDialog` with
/// `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **Reduced to a shell over [OcptBudgetCommitmentFormBody].** Every field, controller and
/// validator this dialog used to hold moved to that widget so the capture wizard can draw the very
/// same form under its own step counter and its own `Back`/`Save` buttons; this class keeps only
/// the title and the two actions.
///
/// **`Save` is withheld here, not merely validated on press, and that is the one thing this shell
/// cannot read off the body's draft alone.** [OcptBudgetCommitmentFormBody.onDraftChanged] answers
/// null the moment the amount does not parse *or* a required field is missing, exactly the
/// distinction this dialog used to blur with a single `_canSubmit` bool — a `Save` gated on the
/// draft alone would grey out the button the instant `Amount` held something unparseable, hiding
/// the field's own inline error a reader could otherwise see by pressing `Save` anyway. So the body
/// also carries [OcptBudgetCommitmentFormBody.onMissingFieldsHintChanged], firing independently of
/// the amount, and this shell gates `Save` and prints the muted hint off *that* signal alone —
/// preserving the dialog's own pre-existing behaviour byte for byte.
class OcptBudgetCommitmentDialog extends StatefulWidget {
  /// The commitment being edited, or null while creating a new one.
  final OcptBudgetCommitment? existing;

  /// Seeds a fresh commitment's own fields while [existing] is null, or null to start from the
  /// dialog's own defaults.
  ///
  /// Set by the quote's own `Commit this line…`, which carries the line's poste, wording, amount
  /// and tax reading across so the only things left to say are the two a quote line does not hold:
  /// who is owed, and when. Mirrors `OcptBudgetEntryDialog.prefill` exactly.
  final OcptBudgetCommitmentFormFields? prefill;

  /// Every live poste of the project, offered by the `Poste` picker while creating.
  final List<OcptBudgetPoste> postes;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null — what the `VAT` field's own hint
  /// reads while it is left empty.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified — switches a poste's own displayed name
  /// exactly as every other view of this mode does.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetCommitmentDialog({
    super.key,
    required this.existing,
    this.prefill,
    required this.postes,
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
  });

  /// Create the [_OcptBudgetCommitmentDialogState] holding the state of the budget commitment
  /// dialog.
  @override
  State<OcptBudgetCommitmentDialog> createState() => _OcptBudgetCommitmentDialogState();

  /// Show the dialog and return the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetCommitmentFormFields?> show(
    BuildContext context, {
    required OcptBudgetCommitment? existing,
    OcptBudgetCommitmentFormFields? prefill,
    required List<OcptBudgetPoste> postes,
    required String currencyCode,
    required int? defaultVatRateBasisPoints,
    required bool isSimplified,
  }) => showDialog<OcptBudgetCommitmentFormFields>(
    context: context,
    builder: (context) => OcptBudgetCommitmentDialog(
      existing: existing,
      prefill: prefill,
      postes: postes,
      currencyCode: currencyCode,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    ),
  );
}

/// The state of [OcptBudgetCommitmentDialog]: the form key it hands to
/// [OcptBudgetCommitmentFormBody], the last draft that body reported, and the missing-fields hint
/// that gates `Save` independently of it — see the class doc comment for why the two are separate.
class _OcptBudgetCommitmentDialogState extends State<OcptBudgetCommitmentDialog> {
  /// The form [OcptBudgetCommitmentFormBody] validates against, owned here since this shell is the
  /// one that decides when to validate it.
  final _formKey = GlobalKey<FormState>();

  /// The fields [OcptBudgetCommitmentFormBody] would submit right now, or null while it cannot be
  /// read at all — see [OcptBudgetCommitmentFormBody.onDraftChanged]'s own doc comment.
  OcptBudgetCommitmentFormFields? _draft;

  /// Which of the two required fields (or both) [OcptBudgetCommitmentFormBody] is still missing, or
  /// null once both are filled — see [OcptBudgetCommitmentFormBody.onMissingFieldsHintChanged]'s
  /// own doc comment.
  String? _missingFieldsHint;

  /// Build the budget commitment dialog as an [AlertDialog].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final missingFieldsHint = _missingFieldsHint;

    return AlertDialog(
      title: Text(
        isEditing ? tr.budgetCommitmentDialogEditTitle : tr.budgetCommitmentDialogCreateTitle,
      ),
      content: OcptBudgetCommitmentFormBody(
        existing: widget.existing,
        prefill: widget.prefill,
        postes: widget.postes,
        currencyCode: widget.currencyCode,
        defaultVatRateBasisPoints: widget.defaultVatRateBasisPoints,
        isSimplified: widget.isSimplified,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _draft = draft),
        onMissingFieldsHintChanged: (hint) => setState(() => _missingFieldsHint = hint),
      ),
      actions: [
        if (missingFieldsHint != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              missingFieldsHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.budgetEntryDialogCancelAction),
        ),
        FilledButton(
          onPressed: missingFieldsHint == null ? _submit : null,
          child: Text(tr.budgetEntryDialogConfirmAction),
        ),
      ],
    );
  }

  /// Validate the form and, if it passes, pop the dialog returning the last draft
  /// [OcptBudgetCommitmentFormBody] reported — mirrors what this dialog's own `_submit` did before
  /// it was split, `Save` already being withheld while [_missingFieldsHint] names something still
  /// missing.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = _draft;
    if (draft == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetCommitmentFormFields>(draft);
  }
}
