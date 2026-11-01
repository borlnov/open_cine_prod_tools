// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_form_body.dart';

/// The dialog that both **creates and edits** a revenue sharing share — one shape for both,
/// mirroring `OcptBudgetResourceDialog`'s own structure exactly: a [Form], an `AlertDialog` with
/// `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **Reduced to a shell over [OcptBudgetShareFormBody].** Every field, controller and validator
/// this dialog used to hold moved to that widget so the capture wizard can draw the very same form
/// under its own step counter and its own `Back`/`Save` buttons; this class keeps only the title
/// and the two actions — see [OcptBudgetShareFormBody]'s own class doc comment for the rest of the
/// argument this doc comment used to carry.
class OcptBudgetShareDialog extends StatefulWidget {
  /// The share being edited, or null while creating a new one.
  final OcptBudgetShare? existing;

  /// Every live person of the project's address book, offered by the `Person` picker alongside its
  /// own explicit "no person" choice.
  final List<OcptPerson> people;

  /// Class constructor
  const OcptBudgetShareDialog({super.key, required this.existing, required this.people});

  /// Create the [_OcptBudgetShareDialogState] holding the state of the budget share dialog.
  @override
  State<OcptBudgetShareDialog> createState() => _OcptBudgetShareDialogState();

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetShareFormFields?> show(
    BuildContext context, {
    required OcptBudgetShare? existing,
    required List<OcptPerson> people,
  }) => showDialog<OcptBudgetShareFormFields>(
    context: context,
    builder: (context) => OcptBudgetShareDialog(existing: existing, people: people),
  );
}

/// The state of [OcptBudgetShareDialog]: the form key it hands to [OcptBudgetShareFormBody] and the
/// last draft that body reported.
class _OcptBudgetShareDialogState extends State<OcptBudgetShareDialog> {
  /// The form [OcptBudgetShareFormBody] validates against, owned here since this shell is the one
  /// that decides when to validate it.
  final _formKey = GlobalKey<FormState>();

  /// The fields [OcptBudgetShareFormBody] would submit right now, or null while it cannot be read
  /// at all — see [OcptBudgetShareFormBody.onDraftChanged]'s own doc comment.
  OcptBudgetShareFormFields? _draft;

  /// Build the budget share dialog as an [AlertDialog].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? tr.budgetShareDialogEditTitle : tr.budgetShareDialogCreateTitle),
      content: OcptBudgetShareFormBody(
        existing: widget.existing,
        people: widget.people,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _draft = draft),
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

  /// Validates the form and, if it passes, pops the dialog returning the last draft
  /// [OcptBudgetShareFormBody] reported — mirrors what this dialog's own `_submit` did before it
  /// was split.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = _draft;
    if (draft == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetShareFormFields>(draft);
  }
}
