// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What `OcptBudgetShareDialog` collected, handed back to the mode that opened it — one shape for
/// both creating and editing a `budget_shares` row, shaped after
/// `OcptBudgetResourceFormFields`'s own reading for the financing plan's own resources.
///
/// **Carries no tax basis, no rate, and no `paidCents` at all**, unlike every other form of this
/// mode: `OcptBudgetSharesTable`'s own doc comment already settles that what a participant has been
/// paid is read off the journal, never typed here.
class OcptBudgetShareFormFields extends Equatable {
  /// The person this share names, or null — a role such as "Production" is a real participant
  /// naming no one person.
  final String? personId;

  /// This share's free-text wording, trimmed — the dialog's own only required field.
  final String label;

  /// This participant's share of the whole pot, in per mille (400 is 40 %).
  final int sharePermille;

  /// The fraction of this participant's *own* [sharePermille] they reinvest in the next
  /// production, in per mille.
  final int reinvestPermille;

  /// Free-form notes about this share, trimmed.
  final String notes;

  /// Class constructor
  const OcptBudgetShareFormFields({
    required this.personId,
    required this.label,
    required this.sharePermille,
    required this.reinvestPermille,
    required this.notes,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetShareFormFields(personId: $personId, label: $label, "
      "sharePermille: $sharePermille, reinvestPermille: $reinvestPermille)";

  /// Object properties
  @override
  List<Object?> get props => [personId, label, sharePermille, reinvestPermille, notes];
}
