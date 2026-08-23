// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_allowances.dart';

/// What the provisioning last wrote into a quote line, as `budget_lines.provisionDigest` stores it:
/// `[label, quantityMilli, unitAmountCents]` as JSON.
///
/// **Deliberately readable rather than hashed**: it lives in a project file somebody may one day
/// open with a SQLite browser, and a hash would say nothing to them. It is only ever compared for
/// equality with a freshly computed one, so it never has to be short.
String ocptBudgetProvisionDigestOf({
  required String label,
  required int quantityMilli,
  required int unitAmountCents,
}) => jsonEncode([label, quantityMilli, unitAmountCents]);

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

  /// Object properties
  @override
  List<Object?> get props => [kind, quantityMilli, unitAmountCents];
}

/// Every figure the régie view currently has to provision, in [OcptBudgetProvisionKind] order.
///
/// **A nature with nothing to say is left out entirely**, the discipline every grouping of this
/// mode keeps: no meal price recorded, or no shooting day at all, and there is no meal figure —
/// which is a different fact from "meals come to nothing", and one that must not become a quote
/// line for a nature the production never used. The same holds for a defrayal nature nobody wrote
/// a row for.
///
/// [mealPriceCents] and [snackPriceCents] are **nullable on purpose**: a project that has never
/// recorded either has not said they are free (`docs/architecture/budget.md`, "null, never zero").
List<OcptBudgetProvisionItem> ocptBudgetProvisionItemsOf({
  required int mealCount,
  required int snackCount,
  required int? mealPriceCents,
  required int? snackPriceCents,
  required List<OcptBudgetAllowance> allowances,
}) {
  final byKind = ocptBudgetAllowancesTotalByKind(allowances);
  const allowanceKinds = <OcptBudgetAllowanceKind, OcptBudgetProvisionKind>{
    OcptBudgetAllowanceKind.travel: OcptBudgetProvisionKind.travelAllowance,
    OcptBudgetAllowanceKind.accommodation: OcptBudgetProvisionKind.accommodationAllowance,
    OcptBudgetAllowanceKind.meal: OcptBudgetProvisionKind.mealAllowance,
    OcptBudgetAllowanceKind.other: OcptBudgetProvisionKind.otherAllowance,
  };

  return [
    if (mealPriceCents != null && mealCount > 0)
      OcptBudgetProvisionItem(
        kind: OcptBudgetProvisionKind.meal,
        quantityMilli: mealCount * 1000,
        unitAmountCents: mealPriceCents,
      ),
    if (snackPriceCents != null && snackCount > 0)
      OcptBudgetProvisionItem(
        kind: OcptBudgetProvisionKind.snack,
        quantityMilli: snackCount * 1000,
        unitAmountCents: snackPriceCents,
      ),
    for (final entry in allowanceKinds.entries)
      if (byKind.containsKey(entry.key))
        OcptBudgetProvisionItem(
          kind: entry.value,
          quantityMilli: 1000,
          unitAmountCents: byKind[entry.key]!,
        ),
  ];
}

/// What provisioning would do to one quote line.
enum OcptBudgetProvisionOutcome {
  /// No line carries this nature's key on the target poste: one is created.
  created,

  /// A line carries it, still holds exactly what the provisioning last wrote, and that no longer
  /// matches the current figure: it is updated.
  updated,

  /// A line carries it and already holds the current figure: nothing is written.
  unchanged,

  /// A line carries it but no longer holds what the provisioning last wrote — somebody edited it by
  /// hand. **It is reported and left exactly as it is**, never overwritten.
  skippedEdited,
}

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

  /// Class constructor
  const OcptBudgetProvisionEntry({
    required this.kind,
    required this.lineId,
    required this.label,
    required this.quantityMilli,
    required this.unitAmountCents,
    required this.outcome,
  });

  /// What the provisioning would stamp onto the line it writes.
  String get digest => ocptBudgetProvisionDigestOf(
    label: label,
    quantityMilli: quantityMilli,
    unitAmountCents: unitAmountCents,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetProvisionEntry(kind: $kind, lineId: $lineId, outcome: $outcome, "
      "quantityMilli: $quantityMilli, unitAmountCents: $unitAmountCents)";

  /// Object properties
  @override
  List<Object?> get props => [kind, lineId, label, quantityMilli, unitAmountCents, outcome];
}

/// Everything the provisioning would do to [posteLines], one entry per nature it touches.
///
/// **The plan is computed whole before a single row is written**, so the gesture can be described
/// to the user in a confirmation before it happens — how many lines would be created, how many
/// updated, and how many left alone because somebody has edited them. Nothing here writes.
///
/// Three rules, and each of them says the same thing in a different place:
///
/// - a nature with a figure and no line yet is **created**;
/// - a nature whose line still holds exactly what the provisioning last wrote is the app's own to
///   **update**, or to leave [OcptBudgetProvisionOutcome.unchanged] when the figure has not moved;
/// - a nature whose line no longer holds what the provisioning last wrote has been **retouched by
///   somebody**, and is reported rather than overwritten. A figure a user typed is never silently
///   corrected — the money rule of this whole mode.
///
/// **A provisioned line whose nature no longer has any figure is updated to nothing**, not deleted
/// and not left standing at a stale amount: it is a line the app wrote and still owns, so leaving
/// yesterday's travel total in the quote after every defrayal has been removed would be the one
/// dishonest option. Deleting it instead would take a decision that belongs to the user, who can
/// see the zero and remove the line.
///
/// [labels] must hold a wording for every nature in [items], and for every nature the provisioned
/// lines of [posteLines] carry: a mode resolves every word and hands it in, no util of this app
/// ever seeing a `Tr`.
List<OcptBudgetProvisionEntry> ocptBudgetProvisionPlanOf({
  required List<OcptBudgetProvisionItem> items,
  required List<OcptBudgetLine> posteLines,
  required Map<OcptBudgetProvisionKind, String> labels,
}) {
  final lineByKey = <String, OcptBudgetLine>{
    for (final line in posteLines)
      if (line.provisionKey != null) line.provisionKey!: line,
  };

  final entries = <OcptBudgetProvisionEntry>[];
  final seen = <String>{};

  for (final item in items) {
    final label = labels[item.kind] ?? "";
    final existing = lineByKey[item.kind.name];
    seen.add(item.kind.name);

    entries.add(
      OcptBudgetProvisionEntry(
        kind: item.kind,
        lineId: existing?.id,
        label: label,
        quantityMilli: item.quantityMilli,
        unitAmountCents: item.unitAmountCents,
        outcome: _outcomeOf(
          existing: existing,
          label: label,
          quantityMilli: item.quantityMilli,
          unitAmountCents: item.unitAmountCents,
        ),
      ),
    );
  }

  // Every provisioned line whose nature has dropped out of `items` — the production removed its
  // last defrayal of that kind, or took back the price the catering was counted at.
  for (final line in posteLines) {
    final key = line.provisionKey;
    if (key == null || seen.contains(key)) {
      continue;
    }

    final kind = OcptBudgetProvisionKind.values.asNameMap()[key];
    if (kind == null) {
      // A key written by a build that knows a nature this one does not: left strictly alone, the
      // way this app leaves alone everything it cannot vouch for.
      continue;
    }

    final label = labels[kind] ?? "";
    entries.add(
      OcptBudgetProvisionEntry(
        kind: kind,
        lineId: line.id,
        label: label,
        quantityMilli: 0,
        unitAmountCents: 0,
        outcome: _outcomeOf(
          existing: line,
          label: label,
          quantityMilli: 0,
          unitAmountCents: 0,
        ),
      ),
    );
  }

  return entries;
}

/// What the provisioning would do to [existing], given the figure it now holds.
OcptBudgetProvisionOutcome _outcomeOf({
  required OcptBudgetLine? existing,
  required String label,
  required int quantityMilli,
  required int unitAmountCents,
}) {
  if (existing == null) {
    return OcptBudgetProvisionOutcome.created;
  }

  final currentDigest = ocptBudgetProvisionDigestOf(
    label: existing.label,
    quantityMilli: existing.quantityMilli,
    unitAmountCents: existing.unitPrice.amountCents,
  );
  if (currentDigest != existing.provisionDigest) {
    return OcptBudgetProvisionOutcome.skippedEdited;
  }

  final wantedDigest = ocptBudgetProvisionDigestOf(
    label: label,
    quantityMilli: quantityMilli,
    unitAmountCents: unitAmountCents,
  );

  return currentDigest == wantedDigest
      ? OcptBudgetProvisionOutcome.unchanged
      : OcptBudgetProvisionOutcome.updated;
}
