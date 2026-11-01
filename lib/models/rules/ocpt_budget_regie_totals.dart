// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie_day.dart';

/// The catering pass folded over every day: how many heads, meals and buffet servings the whole
/// schedule accounts for, and the whole cost.
class OcptBudgetRegieTotals extends Equatable {
  /// The sum of every day's own [OcptBudgetRegieDay.headCount] — a person shooting on three days is
  /// counted three times here, once per day they actually had to be fed, unlike the de-duplication
  /// each day's own count already applies within itself.
  final int headCount;

  /// The sum of every day's own [OcptBudgetRegieDay.mealCount] — a person fed at two sittings of
  /// one day is counted twice, exactly as [OcptBudgetRegieDay.mealCount] already counts them.
  final int mealCount;

  /// The sum of every day's own [OcptBudgetRegieDay.buffetCount].
  final int buffetCount;

  /// Every day's own [OcptBudgetRegieDay.cost], folded together — row by row, then summed, the same
  /// reading `docs/architecture/budget.md` states for every other total in this mode.
  final OcptBudgetCoveredTotal cost;

  /// Class constructor
  const OcptBudgetRegieTotals({
    required this.headCount,
    required this.mealCount,
    required this.buffetCount,
    required this.cost,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetRegieTotals(headCount: $headCount, mealCount: $mealCount, "
      "buffetCount: $buffetCount, cost: $cost)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [headCount, mealCount, buffetCount, cost];
}
