// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';

/// Where a quote line and the breakdown's own elements catalogue cross — the one subject
/// `budget_lines.elementId` exists for.
///
/// A **separate file from `ocpt_budget_totals.dart` and `ocpt_budget_financing.dart`**, for the
/// very reason those two are already kept apart from one another: a quote line's own price and a
/// breakdown element's own record are different subjects, read by different modes, and this file is
/// the one place that reads both at once rather than either of them growing a dependency on the
/// other's shape.

/// Every live quote line's own `elementId`, across every account of [accounts] — the set a fresh
/// `+ From breakdown` picker excludes (an element already priced by a line is not offered a second
/// time) and what the two counts of [OcptBudgetElementLinkCounts] below are read against.
Set<String> ocptBudgetPricedElementIdsOf(List<OcptBudgetAccount> accounts) => {
  for (final account in accounts)
    for (final line in account.lines)
      if (line.elementId != null) line.elementId!,
};

/// How many of a project's own live elements are named by a live quote line's own `elementId`, and
/// how many are not — `OcptBudgetFeedCard`'s own breakdown row reads this pair rather than either
/// count being recomputed in the widget.
class OcptBudgetElementLinkCounts extends Equatable {
  /// How many live elements a live quote line already prices.
  final int pricedCount;

  /// How many live elements no live line prices yet.
  final int unpricedCount;

  /// Class constructor
  const OcptBudgetElementLinkCounts({required this.pricedCount, required this.unpricedCount});

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetElementLinkCounts(pricedCount: $pricedCount, unpricedCount: $unpricedCount)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [pricedCount, unpricedCount];
}

/// Build [OcptBudgetElementLinkCounts] over [accounts] and [elements] — see that class's own doc
/// comment.
OcptBudgetElementLinkCounts ocptBudgetElementLinkCountsOf({
  required List<OcptBudgetAccount> accounts,
  required List<OcptElement> elements,
}) {
  final pricedIds = ocptBudgetPricedElementIdsOf(accounts);
  final pricedCount = elements.where((element) => pricedIds.contains(element.id)).length;

  return OcptBudgetElementLinkCounts(
    pricedCount: pricedCount,
    unpricedCount: elements.length - pricedCount,
  );
}

/// Get every one of [elements] no live quote line of [accounts] prices yet, in [elements]' own
/// order —
/// what `OcptBudgetDetail`'s own `+ From breakdown` picker offers: an element already
/// answered by a line is not offered a second time.
List<OcptElement> ocptBudgetUnpricedElementsOf({
  required List<OcptBudgetAccount> accounts,
  required List<OcptElement> elements,
}) {
  final pricedIds = ocptBudgetPricedElementIdsOf(accounts);
  return [
    for (final element in elements)
      if (!pricedIds.contains(element.id)) element,
  ];
}
