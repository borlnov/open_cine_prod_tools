// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';

/// One figure the régie view has to provision: a nature, how many of it, and at what unit price.
///
/// The **catering** natures carry a real quantity and a real unit price — 28 meals at 12,00 € — so
/// the quote line reads the way a reader would have typed it. The **defrayal** natures carry a
/// quantity of one and the summed total as their unit price: they aggregate across people, dates
/// and mileage scales, and no single unit price exists for a line mixing 168 km at 0,529 €/km with
/// three meals at 15,00 €.
class OcptBudgetProvisionItem extends Equatable {
  /// What this figure is for.
  final OcptBudgetProvisionKind kind;

  /// How many units this figure covers, in thousandths.
  final int quantityMilli;

  /// What one unit costs, in whole cents.
  final int unitAmountCents;

  /// Class constructor
  const OcptBudgetProvisionItem({
    required this.kind,
    required this.quantityMilli,
    required this.unitAmountCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetProvisionItem(kind: $kind, quantityMilli: $quantityMilli, "
      "unitAmountCents: $unitAmountCents)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [kind, quantityMilli, unitAmountCents];
}
