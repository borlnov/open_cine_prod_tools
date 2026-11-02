// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The whole of [OcptBudgetResourceDialog]'s own form, embeddable outside a dialog — the capture
/// wizard draws this same body under its own step counter, rather than an `AlertDialog`'s
/// `content`.
///
/// **`Label` is the dialog's own only required field**, unlike the commitment dialog's own two: a
/// resource's `Group` and `Status` both already carry a sensible default the moment the dialog
/// opens (the first group, [OcptBudgetResourceStatus.pending]), so there is no second field a
/// fresh resource could be missing the way a commitment is missing its account until somebody picks
/// one.
///
/// **The `Group` is fixed, and the picker hidden, while creating** — unless
/// [offerCashOrInKindChoice] says otherwise. `OcptBudgetFinancing`'s own `+ Resource` control and
/// the capture wizard's own step 1 both name a subsidy as its own explicit gesture (*"Ajouter une
/// caméra qui est valorisée n'est pas la même chose que d'ajouter du vrai argent qui va servir à la
/// production pour acheter à manger"*), so a subsidy's own kind is already decided before this body
/// even opens and never asks again: offering the picker there would let the very gesture that named
/// the kind be second-guessed one field later, for no reason a reader could name. **Cash and
/// in-kind are different**: the wizard's own `planContribution` answer collapses the two — *"En
/// numéraire, ou en nature (matériel prêté, équipe bénévole)"* — leaving exactly one question the
/// gesture itself could not settle, so its host passes [offerCashOrInKindChoice] and the picker
/// draws, offering only `cash` and `inKind` rather than all three: a subsidy stays unreachable from
/// it, [groupKind] still seeding which of the two starts selected. Editing is different again:
/// `_OcptResourceGroupKindPicker` always draws there, offering every kind, since a production is
/// free to reclassify a resource it already created, exactly as it is today.
///
/// **The `Amount` field's own label and helper text are worded for the kind picked**, per this
/// whole change's own point: a valuation and real money read the same in every other field, but not
/// in what the figure itself means — see `_amountFieldLabel`/`_amountFieldHelper`.
///
/// **The `Status` picker reads in the kind's own vocabulary**, and this is the other half of the
/// same point: a subsidy is `Applied` for, `Notified`, `Secured`; a cash contribution `Requested`,
/// `Agreed`, `Contracted`; a contribution in kind `Promised`, `Valued`, `Signed`. Asking a
/// production to call a lent camera "applied for" was asking it to file a dossier at a commission
/// that does not exist. **Nothing is hidden or disabled by kind for all that** — the mode's
/// standing rule that the UI carries no conditional branch on the state of the data holds intact:
/// the picker always offers the same three steps, and only their words change with the kind
/// picked, `OcptBudgetResourceStatus`'s own doc comment. The field keeps its own helper worded per
/// kind too (`_statusFieldHelper`). Changing the kind of a resource being edited therefore never
/// invalidates its status: the step survives and simply re-words itself.
///
/// **Carries no tax basis or VAT rate field**, unlike every other form of this mode: see
/// `OcptBudgetResourceFormFields`'s own doc comment for why a financing resource asks for neither.
///
/// **`Person` is a picker offering [people] alongside its own explicit "no person" choice**,
/// mirroring `OcptBudgetShareFormBody`'s own `Person` field exactly: a subsidy usually names
/// nobody, which is the ordinary, legitimate answer here, not an unfinished pick —
/// `OcptBudgetResourcesTable.personId`'s own doc comment.
///
/// **The host owns the submit gesture.** [formKey] is put on this body's own [Form], and
/// [onDraftChanged] fires with the fields this body would submit right now — or null while the
/// `Amount` field's own figure does not parse, the one way this body can be unreadable — every time
/// a field changes, `initState` included so a host that never touches a pre-filled edit still has a
/// draft to submit. The host validates [formKey] and uses the last reported draft on its own
/// `Save`; this body never pops anything itself.
///
/// **The `Poste` field draws only while the picked group reads
/// [OcptBudgetResourceGroupKind.inKind]**, appearing and disappearing the moment the `Group` picker
/// above toggles into or out of it — a subsidy or a cash contribution offsets no account, so the
/// field is not merely disabled for them, it is not drawn at all
/// (`OcptBudgetResourceFormFields.accountId`'s own doc comment). It mirrors
/// `OcptBudgetCommitmentFormBody`'s own account picker, but is validated the way this
/// body's own `Label` field already is — a plain [DropdownButtonFormField] validator — rather than
/// through a separate missing-fields hint: `Amount` is the one field here that can be technically
/// unreadable (its figure fails to parse), which is what forces the current draft to read null and
/// gate `Save` through the draft alone; a missing `Poste`, like a missing `Label`, is instead a
/// plain required-field failure the [Form]'s own `validate()` already reports inline, which
/// `Save`'s own submit handler already calls before ever reading the draft.
class OcptBudgetResourceFormBody extends StatefulWidget {
  /// The resource being edited, or null while creating a new one.
  final OcptBudgetResource? existing;

  /// The kind a fresh resource is created as — see the class doc comment.
  final OcptBudgetResourceGroupKind groupKind;

  /// Every live person of the project's address book, offered by the `Person` picker alongside its
  /// own explicit "no person" choice.
  final List<OcptPerson> people;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// Every live account of the project, offered by the `Poste` picker while the picked group is
  /// [OcptBudgetResourceGroupKind.inKind] — see the class doc comment's own paragraph on the
  /// `Poste` field.
  final List<OcptBudgetAccount> accounts;

  /// The account an existing in-kind contribution's counterpart line currently offsets, or null —
  /// seeds the `Poste` picker's own initial value. Read from the linked counterpart line rather
  /// than from a field of the resource, which stores no account of its own
  /// (`OcptBudgetResourceFormFields.accountId`'s own doc comment).
  final String? initialAccountId;

  /// Whether the mode's header currently reads simplified — switches an account's own displayed
  /// name exactly as every other picker of this mode does.
  final bool isSimplified;

  /// The form this body's own [Form] validates against — the host's to create and to validate.
  final GlobalKey<FormState> formKey;

  /// Called with the fields this body would submit right now, or null while it cannot be read at
  /// all — see the class doc comment.
  final ValueChanged<OcptBudgetResourceFormFields?> onDraftChanged;

  /// Draws the `Group` picker while creating too, offering only [OcptBudgetResourceGroupKind.cash]
  /// and [OcptBudgetResourceGroupKind.inKind] — see the class doc comment. Defaults to false,
  /// [OcptBudgetResourceDialog]'s own reading, which keeps the picker hidden while creating.
  final bool offerCashOrInKindChoice;

  /// Class constructor
  const OcptBudgetResourceFormBody({
    super.key,
    required this.existing,
    required this.groupKind,
    required this.people,
    required this.currencyCode,
    required this.accounts,
    this.initialAccountId,
    required this.isSimplified,
    required this.formKey,
    required this.onDraftChanged,
    this.offerCashOrInKindChoice = false,
  });

  /// Create the [_OcptBudgetResourceFormBodyState] holding the state of the budget resource form
  /// body.
  @override
  State<OcptBudgetResourceFormBody> createState() => _OcptBudgetResourceFormBodyState();
}

/// The state of [OcptBudgetResourceFormBody].
class _OcptBudgetResourceFormBodyState extends State<OcptBudgetResourceFormBody> {
  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the amount field.
  late final TextEditingController _amountController;

  /// The controller of the notes field.
  late final TextEditingController _notesController;

  /// The group kind currently picked — fixed to `widget.groupKind` for as long as this body is
  /// creating, since its own picker is not drawn then; see the class doc comment.
  late OcptBudgetResourceGroupKind _groupKind;

  /// The status currently picked.
  late OcptBudgetResourceStatus _status;

  /// Whether this resource is currently marked reimbursable.
  late bool _isReimbursable;

  /// The person currently picked, or null for "no person" — the normal case for a subsidy, see the
  /// class doc comment.
  String? _personId;

  /// The account currently picked, read only while [_groupKind] is
  /// [OcptBudgetResourceGroupKind.inKind] — see the class doc comment's own paragraph on the
  /// `Poste` field.
  String? _accountId;

  /// Get the fields this body would submit right now, or null while the `Amount` field's own figure
  /// does not parse.
  OcptBudgetResourceFormFields? get _currentDraft {
    final amountCents = ocptCostCentsOf(_amountController.text);
    if (amountCents == null) {
      return null;
    }

    return OcptBudgetResourceFormFields(
      groupKind: _groupKind,
      personId: _personId,
      label: _labelController.text.trim(),
      amountCents: amountCents,
      status: _status,
      isReimbursable: _isReimbursable,
      notes: _notesController.text.trim(),
      accountId: _groupKind == OcptBudgetResourceGroupKind.inKind ? _accountId : null,
    );
  }

  /// Fill the fields from the existing resource, and send the first draft after the first frame.
  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _groupKind = existing?.groupKind ?? widget.groupKind;
    _status = existing?.status ?? OcptBudgetResourceStatus.pending;
    _isReimbursable = existing?.isReimbursable ?? false;
    _personId = existing?.personId;
    _accountId = widget.initialAccountId;

    _labelController = TextEditingController(text: existing?.label ?? "")..addListener(_report);
    _amountController = TextEditingController(text: ocptCostTextOf(existing?.amountCents))
      ..addListener(_report);
    _notesController = TextEditingController(text: existing?.notes ?? "")..addListener(_report);

    // The host's own `Save` may be reached before any field is touched — an edit left exactly as
    // it opened — so the very first draft has to travel without waiting on a keystroke.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _report();
      }
    });
  }

  /// Build the budget resource form body as a [Form].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;

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
            // The `Group` picker is drawn while editing, or while creating if the host asked for
            // it — see the class doc comment for why a fresh resource's kind is otherwise fixed by
            // the gesture that opened this body rather than asked for again here.
            if (isEditing || widget.offerCashOrInKindChoice) ...[
              Text(
                tr.budgetResourceDialogGroupFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              _OcptResourceGroupKindPicker(
                value: _groupKind,
                // Editing offers every kind, since a production may reclassify a resource however
                // it likes; a fresh resource offers only cash and in-kind, the one question
                // `planContribution` itself left open — a subsidy stays unreachable from here.
                choices: isEditing
                    ? OcptBudgetResourceGroupKind.values
                    : const [OcptBudgetResourceGroupKind.cash, OcptBudgetResourceGroupKind.inKind],
                onChanged: (value) {
                  setState(() => _groupKind = value);
                  _report();
                },
              ),
              const SizedBox(height: 12),
            ],
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
              controller: _amountController,
              decoration: InputDecoration(
                labelText: _amountFieldLabel(tr),
                helperText: _amountFieldHelper(tr),
                helperMaxLines: 2,
                suffixText: currencySymbol,
              ),
              validator: (value) => ocptCostCentsOf(value ?? "") == null
                  ? tr.budgetEntryDialogAmountInvalidError
                  : null,
            ),
            if (_groupKind == OcptBudgetResourceGroupKind.inKind) ...[
              const SizedBox(height: 12),
              _OcptResourceAccountField(
                accounts: widget.accounts,
                isSimplified: widget.isSimplified,
                value: _accountId,
                onChanged: (value) {
                  setState(() => _accountId = value);
                  _report();
                },
              ),
            ],
            const SizedBox(height: 12),
            Text(
              tr.budgetCommitmentDialogStatusFieldLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            _OcptResourceStatusPicker(
              groupKind: _groupKind,
              value: _status,
              onChanged: (value) {
                setState(() => _status = value);
                _report();
              },
            ),
            const SizedBox(height: 4),
            Text(
              _statusFieldHelper(tr),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              tr.budgetResourceDialogReimbursableFieldLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            OcptBudgetBinaryChoice(
              value: _isReimbursable,
              trueLabel: tr.budgetResourceDialogReimbursableOption,
              falseLabel: tr.budgetResourceDialogNotReimbursableOption,
              onChanged: (value) {
                setState(() => _isReimbursable = value);
                _report();
              },
            ),
            if (_groupKind == OcptBudgetResourceGroupKind.inKind) ...[
              const SizedBox(height: 4),
              Text(
                tr.budgetResourceDialogReimbursableHelperInKind,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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

  /// Report [_currentDraft] to the host — every controller listener and every picker's own
  /// `onChanged` call this after applying its own change.
  void _report() => widget.onDraftChanged(_currentDraft);

  /// Get the `Amount` field's own label, worded for [_groupKind] — see the class doc comment: an
  /// in-kind contribution's figure is what it is *valued at*, never an amount to be received.
  String _amountFieldLabel(Tr tr) => switch (_groupKind) {
    OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogValuedAtFieldLabel,
    OcptBudgetResourceGroupKind.subsidy ||
    OcptBudgetResourceGroupKind.cash => tr.budgetEntryDialogAmountFieldLabel,
  };

  /// Get the `Amount` field's own helper text, worded for [_groupKind] — this is the field the
  /// product
  /// owner could not tell apart by kind: what the figure actually means differs from one kind to
  /// the next, even though the field itself is asked of all three.
  String _amountFieldHelper(Tr tr) => switch (_groupKind) {
    OcptBudgetResourceGroupKind.subsidy => tr.budgetResourceDialogAmountHelperSubsidy,
    OcptBudgetResourceGroupKind.cash => tr.budgetResourceDialogAmountHelperCash,
    OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogAmountHelperInKind,
  };

  /// Get the `Status` field's own helper text, worded for [_groupKind]. **No status is hidden or
  /// disabled by kind** — only the wording changes, never which of the three steps may be picked:
  /// the mode's standing rule that the UI carries no conditional branch on the state of the data.
  ///
  /// **Why the choice is offered on an in-kind contribution at all, rather than forced off.** The
  /// common case is the one it reads against: a camera lent, a location made available, a vehicle —
  /// valued in the quote, never collected, so nothing can ever come back out. But a co-producer's
  /// contribution in industry — a lab, a post house, a rental company entering the contract — is
  /// recouped from the takings exactly as cash is, and that is the normal counterpart of their
  /// entering it at all. Forcing the choice off would have made this app unable to state an
  /// ordinary co-production, so the helper below states which case is which and leaves the decision
  /// where it belongs.
  String _statusFieldHelper(Tr tr) => switch (_groupKind) {
    OcptBudgetResourceGroupKind.subsidy => tr.budgetResourceDialogStatusHelperSubsidy,
    OcptBudgetResourceGroupKind.cash => tr.budgetResourceDialogStatusHelperCash,
    OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogStatusHelperInKind,
  };

  /// Dispose [_labelController], [_amountController] and [_notesController].
  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

/// The resource form's own `Group` picker: [choices] as a wrapped row of small, clickable chips —
/// mirrors `OcptBudgetCommitmentFormBody`'s own status picker, generic over a different enum.
class _OcptResourceGroupKindPicker extends StatelessWidget {
  /// The picker's current value.
  final OcptBudgetResourceGroupKind value;

  /// The kinds offered — `OcptBudgetResourceGroupKind.values` while editing, cash and in-kind
  /// alone while creating: see [OcptBudgetResourceFormBody]'s own class doc comment.
  final List<OcptBudgetResourceGroupKind> choices;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetResourceGroupKind> onChanged;

  /// Class constructor
  const _OcptResourceGroupKindPicker({
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  /// Build the resource group kind picker as a [Wrap].
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final kind in choices) _segment(context, kind)],
  );

  /// Build one of the picker's own segments.
  Widget _segment(BuildContext context, OcptBudgetResourceGroupKind kind) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = kind == value;

    return InkWell(
      onTap: isActive ? null : () => onChanged(kind),
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
        ),
        child: Text(
          ocptBudgetResourceGroupKindLabel(tr, kind),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// The resource form's own `Status` picker: `OcptBudgetResourceStatus`'s own three steps as a
/// wrapped row of small, clickable chips, painted in [ocptBudgetResourceStatusAccentColor] — the
/// same colour and word the financing view's own status pill reads them in, mirroring
/// `OcptBudgetCommitmentFormBody`'s own `_OcptCommitmentStatusPicker`.
///
/// **[groupKind] words the chips**, and re-words them the moment the picker above changes it: see
/// [OcptBudgetResourceFormBody]'s own class doc comment.
class _OcptResourceStatusPicker extends StatelessWidget {
  /// The group the resource being edited sits in — what each of the three steps is called depends
  /// on it.
  final OcptBudgetResourceGroupKind groupKind;

  /// The picker's current value.
  final OcptBudgetResourceStatus value;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetResourceStatus> onChanged;

  /// Class constructor
  const _OcptResourceStatusPicker({
    required this.groupKind,
    required this.value,
    required this.onChanged,
  });

  /// Build the resource status picker as a [Wrap].
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final status in OcptBudgetResourceStatus.values) _segment(context, status)],
  );

  /// Build one of the picker's own segments, filled in its own accent colour while active.
  Widget _segment(BuildContext context, OcptBudgetResourceStatus status) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = status == value;
    final accent = ocptBudgetResourceStatusAccentColor(theme.colorScheme, status);

    return InkWell(
      onTap: isActive ? null : () => onChanged(status),
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border.all(color: isActive ? accent : theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
        ),
        child: Text(
          ocptBudgetResourceStatusLabel(tr, groupKind, status),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? accent : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// The resource form's own `Poste` field: a picker, drawn only while the group is
/// [OcptBudgetResourceGroupKind.inKind] — the CNC account this contribution offsets, required
/// through its own validator exactly as `Label` already is (see the form body's class doc comment
/// for why this differs from `OcptBudgetCommitmentFormBody`'s own missing-fields hint). Mirrors
/// that body's own account field otherwise, account by account and label by label.
class _OcptResourceAccountField extends StatelessWidget {
  /// The accounts the picker offers.
  final List<OcptBudgetAccount> accounts;

  /// Whether the simplified naming applies to the account labels.
  final bool isSimplified;

  /// The picked account id, or null while none is picked.
  final String? value;

  /// Called with the picked account id.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptResourceAccountField({
    required this.accounts,
    required this.isSimplified,
    required this.value,
    required this.onChanged,
  });

  /// Build the resource account field as a [DropdownButtonFormField].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: tr.budgetResourceDialogAccountFieldLabel,
        helperText: tr.budgetResourceDialogAccountFieldHelper,
        helperMaxLines: 2,
      ),
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            child: Text(ocptBudgetAccountDisplayLabel(account, isSimplified: isSimplified)),
          ),
      ],
      onChanged: onChanged,
      validator: (value) => value == null ? tr.budgetResourceDialogAccountRequiredError : null,
    );
  }
}
