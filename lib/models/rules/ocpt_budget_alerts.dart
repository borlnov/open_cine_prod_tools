// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_account_strain.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_cash_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection_step.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';

/// One thing [ocptComputeBudgetAlerts] found worth a look, mirroring
/// `lib/models/rules/ocpt_schedule_alerts.dart`'s own `OcptScheduleAlert`: a sealed hierarchy
/// rather than one class with a handful of nullable fields, so the page that draws the alerts
/// switches over it exhaustively and never has to guess which fields a given subclass actually
/// fills in.
///
/// **The switch is the discriminant, and there is no other.** A `kind` enum lived here once,
/// copied from the schedule's own alerts where a badge and a panel genuinely group by it; nothing
/// on this side ever read it, so it is gone. A caller that needs to tell two alerts apart switches
/// over this hierarchy, which the compiler checks.
///
/// **Two rules are here, and no more.** The mock-up's own 1,500 € cash floor is deliberately not a
/// third: it was calibrated by nobody, and this mode states no regulatory figure and asks for no
/// threshold (`docs/adr/`) — an alert here has to compute itself from the project's own data and
/// state something anybody can check, exactly as `lib/models/rules/ocpt_schedule_alerts.dart`'s own
/// rules do.
///
/// **No `Tr` and no formatted string here** — `lib/models/rules/` is pure; the page that draws them
/// resolves every word and every colour.
sealed class OcptBudgetAlert extends Equatable {
  /// Class constructor
  const OcptBudgetAlert();
}

/// An account whose paid plus committed already exceeds its own quote
/// (`ocptBudgetAccountStrainOf` answering [OcptBudgetAccountStrain.over]) — one alert per such
/// account, never re-deriving the comparison that function and [ocptBudgetVarianceCents] already
/// answer.
final class OcptBudgetAccountOverQuoteAlert extends OcptBudgetAlert {
  /// The account this alert is about.
  final String accountId;

  /// This account's own quoted total, in cents (`ocptBudgetAccountQuotedTotalCents`).
  final int quotedAmountCents;

  /// What has actually been paid against this account, in cents.
  final int paidCents;

  /// What is still committed against this account, in cents.
  final int committedCents;

  /// By how much [paidCents] plus [committedCents] exceeds [quotedAmountCents] — always positive
  /// here, `ocptBudgetVarianceCents`'s own figure verbatim.
  final int varianceCents;

  /// Class constructor
  const OcptBudgetAccountOverQuoteAlert({
    required this.accountId,
    required this.quotedAmountCents,
    required this.paidCents,
    required this.committedCents,
    required this.varianceCents,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetAccountOverQuoteAlert(accountId: $accountId, varianceCents: $varianceCents)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    accountId,
    quotedAmountCents,
    paidCents,
    committedCents,
    varianceCents,
  ];
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

  /// Class constructor
  const OcptBudgetCashProjectionNegativeAlert({
    required this.balanceCents,
    required this.dueDate,
    required this.fallingDueCents,
    required this.balanceAfterCents,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetCashProjectionNegativeAlert(balanceCents: $balanceCents, dueDate: $dueDate, "
      "balanceAfterCents: $balanceAfterCents)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [balanceCents, dueDate, fallingDueCents, balanceAfterCents];
}

/// Compute the header's alerts band's own two alerts over [accounts] and [commitments] — **both
/// computed, neither configured** (ADR 0027): nothing here advances a
/// figure nobody in the project actually entered.
///
/// An account over its quote is read straight off [ocptBudgetAccountStrainOf] and
/// [ocptBudgetVarianceCents] (`lib/models/rules/ocpt_budget_totals.dart`), never re-derived, over
/// [accounts] in the order they were given — one [OcptBudgetAccountOverQuoteAlert] per account
/// answering [OcptBudgetAccountStrain.over], [paidCentsOf], [committedCentsOf] and
/// [inKindCoveredCentsOf] reading the very same per-account totals the cost-tracking table and the
/// account inspector already do. [inKindCoveredCentsOf] is folded into the strain and the variance
/// for the same reason [ocptBudgetAccountStrainOf] folds it in — a counterpart quote line adds
/// equally to the account's own quote and to its settled side, so it never pushes an account over
/// on its own.
///
/// The cash projection going negative is read straight off [ocptBudgetProjectionOf]
/// (`lib/models/rules/ocpt_budget_projection.dart`), opened at [cashTotals]'s own
/// `OcptBudgetCashTotals.balanceCents` over [commitments], settlement read off [entries] — at most
/// one [OcptBudgetCashProjectionNegativeAlert], present only while that projection's own
/// `OcptBudgetProjection.goesNegative` is true.
List<OcptBudgetAlert> ocptComputeBudgetAlerts({
  required List<OcptBudgetAccount> accounts,
  required int Function(String accountId) paidCentsOf,
  required int Function(String accountId) committedCentsOf,
  required int Function(String accountId) inKindCoveredCentsOf,
  required List<OcptBudgetCommitment> commitments,
  required List<OcptBudgetEntry> entries,
  required OcptBudgetCashTotals cashTotals,
  required int? projectVatRateBasisPoints,
}) {
  final alerts = <OcptBudgetAlert>[];

  for (final account in accounts) {
    final quotedAmountCents = ocptBudgetAccountQuotedTotalCents(account);
    final paidCents = paidCentsOf(account.id);
    final committedCents = committedCentsOf(account.id);
    final inKindCoveredCents = inKindCoveredCentsOf(account.id);

    final strain = ocptBudgetAccountStrainOf(
      quotedAmountCents: quotedAmountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
    );
    if (strain != OcptBudgetAccountStrain.over) {
      continue;
    }

    alerts.add(
      OcptBudgetAccountOverQuoteAlert(
        accountId: account.id,
        quotedAmountCents: quotedAmountCents,
        paidCents: paidCents,
        committedCents: committedCents,
        varianceCents: ocptBudgetVarianceCents(
          quotedAmountCents: quotedAmountCents,
          paidCents: paidCents,
          committedCents: committedCents,
          inKindCoveredCents: inKindCoveredCents,
        ),
      ),
    );
  }

  final projection = ocptBudgetProjectionOf(
    openingBalanceCents: cashTotals.balanceCents,
    commitments: commitments,
    entries: entries,
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
