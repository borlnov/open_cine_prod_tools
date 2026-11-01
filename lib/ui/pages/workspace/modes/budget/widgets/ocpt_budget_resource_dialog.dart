// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_form_body.dart';

/// The dialog that both **creates and edits** a financing resource — one shape for both, mirroring
/// `OcptBudgetCommitmentDialog`'s own structure exactly, [show] and all: a [Form], an `AlertDialog`
/// with `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **Reduced to a shell over [OcptBudgetResourceFormBody].** Every field, controller and validator
/// this dialog used to hold moved to that widget so the capture wizard can draw the very same form
/// under its own step counter and its own `Back`/`Save` buttons; this class keeps only the title
/// and the two actions.
///
/// **The title alone still depends on the kind being created**, and stays here rather than moving
/// to the body: `_titleOf` reads only [existing], [groupKind] and [offerCashOrInKindChoice], never
/// the body's own live `_groupKind` state — while creating without [offerCashOrInKindChoice], that
/// state starts at [groupKind] and can never change, its own picker being drawn only while editing
/// (see [OcptBudgetResourceFormBody]'s own class doc comment), and while editing the title is the
/// plain, kind-agnostic one regardless. Both readings this shell already has on its own `widget`.
class OcptBudgetResourceDialog extends StatefulWidget {
  /// The resource being edited, or null while creating a new one.
  final OcptBudgetResource? existing;

  /// The kind a fresh resource is created as, and the one `_OcptResourceGroupKindPicker` starts on
  /// while [offerCashOrInKindChoice] — ignored while [existing] is not null, whose own
  /// [OcptBudgetResource.groupKind] is read instead. See [OcptBudgetResourceFormBody]'s own class
  /// doc comment for why creation otherwise fixes the kind rather than asking again.
  final OcptBudgetResourceGroupKind groupKind;

  /// Every live person of the project's address book, offered by the `Person` picker alongside its
  /// own explicit "no person" choice.
  final List<OcptPerson> people;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// Every live poste of the project, offered by the `Poste` picker while the resource being
  /// created or edited is an in-kind contribution — see [OcptBudgetResourceFormBody]'s own class
  /// doc comment.
  final List<OcptBudgetPoste> postes;

  /// The poste an existing in-kind contribution's counterpart line currently offsets, or null —
  /// seeds the `Poste` picker while editing. Read from the linked line rather than from a field of
  /// the resource itself, which stores no poste of its own
  /// (`OcptBudgetResourceFormFields.posteId`'s own doc comment). Ignored while creating: a fresh
  /// resource has no counterpart line yet.
  final String? initialPosteId;

  /// Whether the mode's header currently reads simplified — switches a poste's own displayed name
  /// exactly as every other picker of this mode does.
  final bool isSimplified;

  /// Forwarded to [OcptBudgetResourceFormBody] — see its own class doc comment. Defaults to false.
  final bool offerCashOrInKindChoice;

  /// Class constructor
  const OcptBudgetResourceDialog({
    super.key,
    required this.existing,
    required this.groupKind,
    required this.people,
    required this.currencyCode,
    required this.postes,
    this.initialPosteId,
    required this.isSimplified,
    this.offerCashOrInKindChoice = false,
  });

  /// Create the [_OcptBudgetResourceDialogState] holding the state of the budget resource dialog.
  @override
  State<OcptBudgetResourceDialog> createState() => _OcptBudgetResourceDialogState();

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetResourceFormFields?> show(
    BuildContext context, {
    required OcptBudgetResource? existing,
    required OcptBudgetResourceGroupKind groupKind,
    required List<OcptPerson> people,
    required String currencyCode,
    required List<OcptBudgetPoste> postes,
    String? initialPosteId,
    required bool isSimplified,
    bool offerCashOrInKindChoice = false,
  }) => showDialog<OcptBudgetResourceFormFields>(
    context: context,
    builder: (context) => OcptBudgetResourceDialog(
      existing: existing,
      groupKind: groupKind,
      people: people,
      currencyCode: currencyCode,
      postes: postes,
      initialPosteId: initialPosteId,
      isSimplified: isSimplified,
      offerCashOrInKindChoice: offerCashOrInKindChoice,
    ),
  );
}

/// The state of [OcptBudgetResourceDialog]: the form key it hands to [OcptBudgetResourceFormBody]
/// and the last draft that body reported.
class _OcptBudgetResourceDialogState extends State<OcptBudgetResourceDialog> {
  /// The form [OcptBudgetResourceFormBody] validates against, owned here since this shell is the
  /// one that decides when to validate it.
  final _formKey = GlobalKey<FormState>();

  /// The fields [OcptBudgetResourceFormBody] would submit right now, or null while it cannot be
  /// read at all — see [OcptBudgetResourceFormBody.onDraftChanged]'s own doc comment.
  OcptBudgetResourceFormFields? _draft;

  /// Build the budget resource dialog as an [AlertDialog].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(_titleOf(tr, isEditing: isEditing)),
      content: OcptBudgetResourceFormBody(
        existing: widget.existing,
        groupKind: widget.groupKind,
        people: widget.people,
        currencyCode: widget.currencyCode,
        postes: widget.postes,
        initialPosteId: widget.initialPosteId,
        isSimplified: widget.isSimplified,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _draft = draft),
        offerCashOrInKindChoice: widget.offerCashOrInKindChoice,
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.budgetEntryDialogCancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(tr.budgetEntryDialogConfirmAction)),
      ],
    );
  }

  /// This dialog's own title: the kind-specific creation title while creating a fixed kind (`New
  /// subsidy`, `New cash contribution`, `New in-kind contribution`), the kind-agnostic
  /// `New contribution` while creating with [OcptBudgetResourceDialog.offerCashOrInKindChoice] —
  /// [OcptBudgetResourceDialog.groupKind] only seeds which of the two the picker starts on, so no
  /// one kind's name belongs in the title there either — and the plain, kind-agnostic edit title
  /// otherwise, for the very same reason. See the class doc comment for why this never needs the
  /// body's own live `_groupKind`.
  String _titleOf(Tr tr, {required bool isEditing}) {
    if (isEditing) {
      return tr.budgetResourceDialogEditTitle;
    }
    if (widget.offerCashOrInKindChoice) {
      return tr.budgetResourceDialogCreateContributionTitle;
    }

    return switch (widget.groupKind) {
      OcptBudgetResourceGroupKind.subsidy => tr.budgetResourceDialogCreateSubsidyTitle,
      OcptBudgetResourceGroupKind.cash => tr.budgetResourceDialogCreateCashTitle,
      OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogCreateInKindTitle,
    };
  }

  /// Validates the form and, if it passes, pops the dialog returning the last draft
  /// [OcptBudgetResourceFormBody] reported — mirrors what this dialog's own `_submit` did before it
  /// was split.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = _draft;
    if (draft == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetResourceFormFields>(draft);
  }
}
