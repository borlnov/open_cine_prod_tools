// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// A per-kilometre reimbursement rate the production names for itself. See
/// `OcptBudgetMileageRatesTable`'s own doc comment for why this app states no scale of its own, and
/// for [ratePerKmMilliCents]'s unit.
class OcptBudgetMileageRate extends Equatable {
  /// The stable, unique id of this rate (a UUID).
  final String id;

  /// This rate's display name.
  final String label;

  /// The reimbursement rate, in thousandths of a cent per kilometre — see
  /// `OcptBudgetMileageRatesTable.ratePerKmMilliCents`'s own doc comment.
  final int ratePerKmMilliCents;

  /// This rate's position within the project's own flat `sortKey` order.
  final String sortKey;

  /// Class constructor
  const OcptBudgetMileageRate({
    required this.id,
    required this.label,
    required this.ratePerKmMilliCents,
    required this.sortKey,
  });

  /// Builds an [OcptBudgetMileageRate] from its stored [row].
  factory OcptBudgetMileageRate.fromRow(OcptBudgetMileageRateRow row) => OcptBudgetMileageRate(
    id: row.id,
    label: row.label,
    ratePerKmMilliCents: row.ratePerKmMilliCents,
    sortKey: row.sortKey,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetMileageRate(id: $id, label: $label, "
      "ratePerKmMilliCents: $ratePerKmMilliCents)";

  /// Object properties
  @override
  List<Object?> get props => [id, label, ratePerKmMilliCents, sortKey];
}
