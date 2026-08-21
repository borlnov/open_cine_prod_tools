// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';

/// What `OcptBudgetCommitmentDialog` collected, handed back to the mode that opened it — one shape
/// for both creating and editing a `budget_commitments` row, shaped after
/// `OcptBudgetEntryFormFields`'s own reading for the journal's own entries.
///
/// **[posteId] is only ever read by the mode's own creation handler.**
/// `OcptBudgetJournalService.updateCommitment` carries no `posteId` parameter at all: a
/// commitment's own poste is fixed the moment it is created, exactly as a quote line's `posteId` is
/// (`OcptBudgetQuoteService.updateLine`'s own doc comment) — so `OcptBudgetCommitmentDialog` only
/// ever offers the poste picker while creating, showing it as a plain, uneditable label while
/// editing, and the mode's own update handler never passes this field on.
///
/// [vatRateBasisPoints] carries the very same "null means inherit the project's rate" reading
/// `OcptBudgetEntryFormFields.vatRateBasisPoints`'s own doc comment argues for, and for the same
/// reason: this dialog submits a whole record at once, through one explicit `Save` action nobody
/// reaches without meaning to, so an empty or unparseable submission is never mistaken for a stray
/// keystroke clearing an override on purpose.
class OcptBudgetCommitmentFormFields extends Equatable {
  /// The date this commitment falls due, or null — a real state, never a placeholder for today.
  final DateTime? dueDate;

  /// This commitment's free-text wording, trimmed — the dialog's own first required field.
  final String label;

  /// The poste this commitment prices — the dialog's own second required field. See the class doc
  /// comment for why this is only ever read on creation.
  final String posteId;

  /// The amount committed, in cents, exactly as typed.
  final int amountCents;

  /// Whether [amountCents] already includes tax.
  final bool isTaxInclusive;

  /// The VAT rate this commitment's figures carry, in basis points, or null — see the class doc
  /// comment.
  final int? vatRateBasisPoints;

  /// How far this commitment has progressed towards being paid.
  final OcptBudgetCommitmentStatus status;

  /// Class constructor
  const OcptBudgetCommitmentFormFields({
    required this.dueDate,
    required this.label,
    required this.posteId,
    required this.amountCents,
    required this.isTaxInclusive,
    required this.vatRateBasisPoints,
    required this.status,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetCommitmentFormFields(dueDate: $dueDate, label: $label, posteId: $posteId, "
      "status: $status)";

  /// Object properties
  @override
  List<Object?> get props => [
    dueDate,
    label,
    posteId,
    amountCents,
    isTaxInclusive,
    vatRateBasisPoints,
    status,
  ];
}
