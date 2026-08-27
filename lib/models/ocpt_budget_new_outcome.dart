// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';

/// What `OcptBudgetNewDialog` (the capture wizard) collected, handed back to the mode that opened
/// it — one variant per payload the mode has to dispatch, one `OcptBudgetGesture` mapping onto
/// exactly one of them.
///
/// **`OcptBudgetEntryWizardResult` is one of this sealed type's own variants, not a payload wrapped
/// inside another one.** It already carried exactly the shape the seven `cashMovement` gestures
/// need — an entry draft plus the accepted lettrage suggestion, if any — so it joins this hierarchy
/// directly rather than a second class duplicating its two fields under a new name.
///
/// The mode switches over this exhaustively and dispatches the event that already exists for each
/// variant: nothing here writes to the project itself.
sealed class OcptBudgetNewOutcome extends Equatable {
  /// Class constructor
  const OcptBudgetNewOutcome();
}

/// The seven `cashMovement` gestures' own outcome — [fields] alone for an ordinary save, or
/// [fields] **and** [acceptedSuggestion] when step 3's own reconciliation strip was accepted
/// through `C'est ça` instead. Also what `OcptBudgetEntryDialog.show` hands back while editing an
/// existing entry, [acceptedSuggestion] always null there (that dialog draws no strip at all while
/// editing).
///
/// **Never turned into a domain write by whichever dialog produced it** — that mapping (a
/// commitment settles, a resource or a revenue receives, a defrayal only ever leaves its own label
/// behind) stays in `budget_mode.dart`, exactly where it lived for the capture band the wizard
/// replaces (`OcptBudgetMode`'s own accepted-suggestion handler), because only the mode holds the
/// full commitments list a settlement needs to read a poste and a tax rate off. [fields] therefore
/// carries the plain draft the strip was shown against — no poste, resource, revenue or share named
/// — and the mode reads [acceptedSuggestion] to decide what those four fields ought to have been
/// before dispatching anything.
class OcptBudgetEntryWizardResult extends OcptBudgetNewOutcome {
  /// The typed draft — plain, unenriched, exactly as `Save` would have submitted it had the strip
  /// been ignored.
  final OcptBudgetEntryFormFields fields;

  /// The suggestion `C'est ça` accepted, or null for an ordinary save.
  final OcptBudgetMatchSuggestion? acceptedSuggestion;

  /// Class constructor
  const OcptBudgetEntryWizardResult({required this.fields, required this.acceptedSuggestion});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetEntryWizardResult(fields: $fields, acceptedSuggestion: $acceptedSuggestion)";

  /// Object properties
  @override
  List<Object?> get props => [fields, acceptedSuggestion];
}

/// `addQuoteLine`: a single quote line, priced by hand, born filled inside poste [posteId].
class OcptBudgetNewLineOutcome extends OcptBudgetNewOutcome {
  /// The poste the new line belongs to — the wizard's own step 2 answer.
  final String posteId;

  /// Every field the wizard's own step 3 collected.
  final OcptBudgetLineFormFields fields;

  /// Class constructor
  const OcptBudgetNewLineOutcome({required this.posteId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [posteId, fields];
}

/// `addQuoteLinesFromBreakdown`: several quote lines at once, each priced against a breakdown
/// element the reader picked and, optionally, corrected the suggested quantity of.
class OcptBudgetNewLinesFromBreakdownOutcome extends OcptBudgetNewOutcome {
  /// One entry per line to create: the breakdown element it prices, the poste the reader filed it
  /// under — chosen per element on the selector's own step, so two elements of one selection can
  /// land in two different postes — and the quantity to create it with (the scene count the
  /// breakdown suggests, or whatever the reader corrected it to).
  final List<({String elementId, String posteId, int quantityMilli})> lines;

  /// Class constructor
  const OcptBudgetNewLinesFromBreakdownOutcome({required this.lines});

  /// Object properties
  @override
  List<Object?> get props => [lines];
}

/// `commitSpend`: a commitment, promoted from a quote line or hanging off a poste directly.
class OcptBudgetNewCommitmentOutcome extends OcptBudgetNewOutcome {
  /// Every field the wizard's own step 3 collected.
  final OcptBudgetCommitmentFormFields fields;

  /// The quote line this commitment was promoted from, or null while it hangs off the poste alone
  /// — mirrors `OcptBudgetCommitmentCreationConfirmedEvent.lineId`.
  final String? lineId;

  /// Class constructor
  const OcptBudgetNewCommitmentOutcome({required this.fields, this.lineId});

  /// Object properties
  @override
  List<Object?> get props => [fields, lineId];
}

/// `planSubsidy` / `planContribution`: a financing resource, promised but not yet arrived.
class OcptBudgetNewResourceOutcome extends OcptBudgetNewOutcome {
  /// Every field the wizard's own step 3 collected.
  final OcptBudgetResourceFormFields fields;

  /// Class constructor
  const OcptBudgetNewResourceOutcome({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [fields];
}

/// `planTaking`: a taking the film is expected to earn.
class OcptBudgetNewRevenueOutcome extends OcptBudgetNewOutcome {
  /// Every field the wizard's own step 3 collected.
  final OcptBudgetRevenueFormFields fields;

  /// Class constructor
  const OcptBudgetNewRevenueOutcome({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [fields];
}

/// `defrayPerson`: a défraiement owed to a person.
class OcptBudgetNewAllowanceOutcome extends OcptBudgetNewOutcome {
  /// Every field the wizard's own step 3 collected.
  final OcptBudgetAllowanceFormFields fields;

  /// Class constructor
  const OcptBudgetNewAllowanceOutcome({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [fields];
}

/// `addSharingParticipant`: a new participant in the revenue-sharing split.
class OcptBudgetNewShareOutcome extends OcptBudgetNewOutcome {
  /// Every field the wizard's own step 3 collected.
  final OcptBudgetShareFormFields fields;

  /// Class constructor
  const OcptBudgetNewShareOutcome({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [fields];
}
