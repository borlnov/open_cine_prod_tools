// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';

/// What `OcptBudgetEntryDialog.show` hands back — [fields] alone for an ordinary save, or [fields]
/// **and** [acceptedSuggestion] when step 2's own reconciliation strip was accepted through
/// `C'est ça` instead.
///
/// **The dialog never turns [acceptedSuggestion] into a domain write itself** — that mapping (a
/// commitment settles, a resource or a revenue receives, a defrayal only ever leaves its own label
/// behind) stays in `budget_mode.dart`, exactly where it lived for the capture band this wizard
/// replaces (`OcptBudgetMode`'s own accepted-suggestion handler), because only the mode holds the
/// full commitments list a settlement needs to read a poste and a tax rate off. [fields] therefore
/// carries the plain draft the strip was shown against — no poste, resource, revenue or share named
/// — and the mode reads [acceptedSuggestion] to decide what those four fields ought to have been
/// before dispatching anything.
class OcptBudgetEntryWizardResult extends Equatable {
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
