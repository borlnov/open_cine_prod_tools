// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Which of the dashboard's two rules raised an [OcptBudgetAlert].
///
/// **Two rules are here, and no more.** The mock-up's own 1,500 € cash floor is deliberately not a
/// third: it was calibrated by nobody, and this mode states no regulatory figure and asks for no
/// threshold (`docs/adr/`) — an alert here has to compute itself from the project's own data and
/// state something anybody can check, exactly as `lib/utils/ocpt_schedule_alerts.dart`'s own rules
/// do.
enum OcptBudgetAlertKind {
  /// [OcptBudgetPosteOverQuoteAlert].
  posteOverQuote,

  /// [OcptBudgetCashProjectionNegativeAlert].
  cashProjectionNegative,
}

/// One thing [ocptComputeBudgetAlerts] found worth a look, mirroring
/// `lib/utils/ocpt_schedule_alerts.dart`'s own `OcptScheduleAlert`: a sealed hierarchy rather than
/// one class with a handful of nullable fields, so the dashboard switches over it exhaustively and
/// never has to guess which fields a given [kind] actually fills in.
///
/// **No `Tr` and no formatted string here** — `lib/utils/` is pure; the dashboard resolves every
/// word and every colour.
sealed class OcptBudgetAlert extends Equatable {
  /// Class constructor
  const OcptBudgetAlert();

  /// Which of the two rules raised this alert.
  OcptBudgetAlertKind get kind;
}

/// A poste whose paid plus committed already exceeds its own quote
/// (`ocptBudgetPosteStrainOf` answering [OcptBudgetPosteStrain.over]) — one alert per such poste,
/// never re-deriving the comparison that function and [ocptBudgetVarianceCents] already answer.
final class OcptBudgetPosteOverQuoteAlert extends OcptBudgetAlert {
  /// Class constructor
  const OcptBudgetPosteOverQuoteAlert({
    required this.posteId,
    required this.quotedAmountCents,
    required this.paidCents,
    required this.committedCents,
    required this.varianceCents,
  });

  /// The poste this alert is about.
  final String posteId;

  /// This poste's own quoted total, in cents (`ocptBudgetPosteQuotedTotalCents`).
  final int quotedAmountCents;

  /// What has actually been paid against this poste, in cents.
  final int paidCents;

  /// What is still committed against this poste, in cents.
  final int committedCents;

  /// By how much [paidCents] plus [committedCents] exceeds [quotedAmountCents] — always positive
  /// here, `ocptBudgetVarianceCents`'s own figure verbatim.
  final int varianceCents;

  /// This alert's own kind.
  @override
  OcptBudgetAlertKind get kind => OcptBudgetAlertKind.posteOverQuote;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetPosteOverQuoteAlert(posteId: $posteId, varianceCents: $varianceCents)";

  /// Object properties
  @override
  List<Object?> get props => [posteId, quotedAmountCents, paidCents, committedCents, varianceCents];
}

/// The cash projection (`ocptBudgetProjectionOf`, opened at the journal's own
/// `OcptBudgetCashTotals.balanceCents` over the project's unsettled commitments) going negative —
/// at most one of these, since [ocptBudgetProjectionOf] answers a single
/// `OcptBudgetProjection.firstNegativeStep`.
///
/// [dueDate] mirrors that step's own [OcptBudgetProjectionStep.dueDate] verbatim: **null is a
/// different fact from this alert not existing at all** — the projection does go under, but on no
/// date anybody has recorded. A reader must word the two differently rather than let the undated
/// one silently print an empty date or fall back to today.
final class OcptBudgetCashProjectionNegativeAlert extends OcptBudgetAlert {
  /// Class constructor
  const OcptBudgetCashProjectionNegativeAlert({
    required this.balanceCents,
    required this.dueDate,
    required this.fallingDueCents,
    required this.balanceAfterCents,
  });

  /// The journal's own balance today (`OcptBudgetCashTotals.balanceCents`), before the instalment
  /// that tips it under is taken out.
  final int balanceCents;

  /// The date the instalment that tips the balance under falls due, or null — see the class doc
  /// comment.
  final DateTime? dueDate;

  /// The instalment's own cash figure, in cents, taken out of [balanceCents].
  final int fallingDueCents;

  /// The balance once that instalment has fallen — negative, `OcptBudgetProjectionStep
  /// .balanceAfterCents` verbatim.
  final int balanceAfterCents;

  /// This alert's own kind.
  @override
  OcptBudgetAlertKind get kind => OcptBudgetAlertKind.cashProjectionNegative;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetCashProjectionNegativeAlert(balanceCents: $balanceCents, dueDate: $dueDate, "
      "balanceAfterCents: $balanceAfterCents)";

  /// Object properties
  @override
  List<Object?> get props => [balanceCents, dueDate, fallingDueCents, balanceAfterCents];
}

/// Computes the budget dashboard's own two alerts over [postes] and [commitments] — **both
/// computed, neither configured** (ADR 0027): nothing here advances a
/// figure nobody in the project actually entered.
///
/// A poste over its quote is read straight off [ocptBudgetPosteStrainOf] and
/// [ocptBudgetVarianceCents] (`lib/utils/ocpt_budget_totals.dart`), never re-derived, over
/// [postes] in the order they were given — one [OcptBudgetPosteOverQuoteAlert] per poste answering
/// [OcptBudgetPosteStrain.over], [paidCentsOf] and [committedCentsOf] reading the very same
/// per-poste totals the cost-tracking table and the poste inspector already do.
///
/// The cash projection going negative is read straight off [ocptBudgetProjectionOf]
/// (`lib/utils/ocpt_budget_projection.dart`), opened at [cashTotals]'s own
/// `OcptBudgetCashTotals.balanceCents` over [commitments] — at most one
/// [OcptBudgetCashProjectionNegativeAlert], present only while that projection's own
/// `OcptBudgetProjection.goesNegative` is true.
List<OcptBudgetAlert> ocptComputeBudgetAlerts({
  required List<OcptBudgetPoste> postes,
  required int Function(String posteId) paidCentsOf,
  required int Function(String posteId) committedCentsOf,
  required List<OcptBudgetCommitment> commitments,
  required OcptBudgetCashTotals cashTotals,
  required int? projectVatRateBasisPoints,
}) {
  final alerts = <OcptBudgetAlert>[];

  for (final poste in postes) {
    final quotedAmountCents = ocptBudgetPosteQuotedTotalCents(poste);
    final paidCents = paidCentsOf(poste.id);
    final committedCents = committedCentsOf(poste.id);

    final strain = ocptBudgetPosteStrainOf(
      quotedAmountCents: quotedAmountCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );
    if (strain != OcptBudgetPosteStrain.over) {
      continue;
    }

    alerts.add(
      OcptBudgetPosteOverQuoteAlert(
        posteId: poste.id,
        quotedAmountCents: quotedAmountCents,
        paidCents: paidCents,
        committedCents: committedCents,
        varianceCents: ocptBudgetVarianceCents(
          quotedAmountCents: quotedAmountCents,
          paidCents: paidCents,
          committedCents: committedCents,
        ),
      ),
    );
  }

  final projection = ocptBudgetProjectionOf(
    openingBalanceCents: cashTotals.balanceCents,
    commitments: commitments,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );
  final firstNegativeStep = projection.firstNegativeStep;
  if (firstNegativeStep != null) {
    alerts.add(
      OcptBudgetCashProjectionNegativeAlert(
        balanceCents: cashTotals.balanceCents,
        dueDate: firstNegativeStep.dueDate,
        fallingDueCents: firstNegativeStep.amountCents,
        balanceAfterCents: firstNegativeStep.balanceAfterCents,
      ),
    );
  }

  return alerts;
}
