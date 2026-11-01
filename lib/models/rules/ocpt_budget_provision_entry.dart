// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';

/// One line the provisioning would create, update, leave alone or report.
class OcptBudgetProvisionEntry extends Equatable {
  /// What this entry is for.
  final OcptBudgetProvisionKind kind;

  /// The quote line this entry acts on, or null while it would be created.
  final String? lineId;

  /// The wording the line carries — resolved by the mode and handed in, never built here.
  final String label;

  /// The quantity the line would carry, in thousandths.
  final int quantityMilli;

  /// The unit price the line would carry, in whole cents.
  final int unitAmountCents;

  /// What the provisioning would do to it.
  final OcptBudgetProvisionOutcome outcome;

  /// What the provisioning would stamp onto the line it writes.
  String get digest => ocptBudgetProvisionDigestOf(
    label: label,
    quantityMilli: quantityMilli,
    unitAmountCents: unitAmountCents,
  );

  /// Class constructor
  const OcptBudgetProvisionEntry({
    required this.kind,
    required this.lineId,
    required this.label,
    required this.quantityMilli,
    required this.unitAmountCents,
    required this.outcome,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetProvisionEntry(kind: $kind, lineId: $lineId, outcome: $outcome, "
      "quantityMilli: $quantityMilli, unitAmountCents: $unitAmountCents)";

  /// Object properties
  @override
  List<Object?> get props => [kind, lineId, label, quantityMilli, unitAmountCents, outcome];
}
