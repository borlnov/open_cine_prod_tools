// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_match_candidate_kind.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';

/// One object [ocptBudgetMatchSuggestionsOf] found worth offering, and *why* — carrying no domain
/// object of its own (the caller already holds the commitments, defrayals, resources and revenues
/// this was built from, and looks the row up by [candidateId]) and no word this file invented.
///
/// Modelled on the pure structures already beside it (`OcptBudgetAlert`,
/// `OcptBudgetProjectionStep`): `Equatable`, a doc comment on every member, nothing formatted.
class OcptBudgetMatchSuggestion extends Equatable {
  /// Which ledger [candidateId] names.
  final OcptBudgetMatchCandidateKind kind;

  /// The id of the matched row — a commitment, a defrayal, a resource or a revenue, in whichever
  /// table [kind] says.
  final String candidateId;

  /// The matched row's own free-text wording.
  final String label;

  /// The matched row's own full amount, in cents, or null only for a commitment whose cash figure
  /// cannot be read (`ocptBudgetCommitmentCashCentsOf` answering null — the rate it would need is
  /// unknown). A defrayal, a resource and a revenue never answer null here: none of the three ever
  /// needs a VAT rate to state its own figure.
  final int? amountCents;

  /// When the matched row falls due or is expected, or null: a commitment's own `dueDate` and a
  /// defrayal's own `date` are themselves nullable (nobody has recorded one), a revenue's own
  /// `date` never is, and a resource carries no date of its own at all.
  final DateTime? date;

  /// What the draft movement would actually settle if matched to this row, in cents, or null
  /// exactly when [amountCents] is for a defrayal (which is always owed or unpaid in full, so this
  /// equals [amountCents] verbatim); a commitment, a resource or a revenue may already be partly
  /// paid or received, so this is [amountCents] minus what has already moved against it —
  /// [ocptBudgetCommitmentOutstandingCentsOf] for a commitment, the same reading
  /// `ocptBudgetResourceOutstandingCents` already gives a resource: a resource quoted at 10 000 €
  /// having already received 7 000 € is matched by a 3 000 € receipt, not a 10 000 € one.
  final int? outstandingCents;

  /// Whether [outstandingCents] equals the draft's own amount to the cent — the fact a user
  /// actually recognises, and the ranking's own first key.
  final bool matchesAmount;

  /// Whether [date] falls within the "close" window of the draft's own date — see
  /// [ocptBudgetMatchSuggestionsOf]'s own doc comment for the window and why it is that wide.
  /// Always false when [date] is null: a resource offers no date to be close to, which is a fact
  /// about its own nature, not evidence against the match.
  final bool matchesDate;

  /// Whether [label] shares at least one significant word with the draft's own wording, compared
  /// case- and accent-insensitively — see [ocptBudgetMatchSuggestionsOf]'s own doc comment for the
  /// measure.
  final bool matchesWording;

  /// Class constructor
  const OcptBudgetMatchSuggestion({
    required this.kind,
    required this.candidateId,
    required this.label,
    required this.amountCents,
    required this.date,
    required this.outstandingCents,
    required this.matchesAmount,
    required this.matchesDate,
    required this.matchesWording,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetMatchSuggestion(kind: $kind, candidateId: $candidateId, label: $label, "
      "outstandingCents: $outstandingCents, matchesAmount: $matchesAmount, "
      "matchesDate: $matchesDate, matchesWording: $matchesWording)";

  /// Object properties
  @override
  List<Object?> get props => [
    kind,
    candidateId,
    label,
    amountCents,
    date,
    outstandingCents,
    matchesAmount,
    matchesDate,
    matchesWording,
  ];
}
