// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// What every document built off the budget mode's own figures prints in place of a value that
/// cannot be read at all — an in-kind resource's own received/outstanding while no journal entry
/// names it, or a cash-journal row whose running balance a movement of unknown size left open. The
/// budget mode's own screen keeps the very same mark (`ocptBudgetEmptyValue`,
/// `lib/ui/utils/ocpt_budget_labels.dart`), reached from a `BuildContext` this manager-layer file
/// has none of — this is that same fact, stated once here for every export rather than the screen's
/// own copy, which stays out of reach of a service that must not depend on `lib/ui/`.
const String ocptBudgetExportEmptyValue = "—";

/// [cents] formatted with [currencyCode]'s own symbol and grouping — `NumberFormat.simpleCurrency`,
/// the same formula the mode's own `ocptBudgetAmountLabel` reads an amount with on screen. Restated
/// here rather than imported for the same reason [ocptBudgetExportEmptyValue] is: that formatter
/// lives in `lib/ui/utils/`, out of reach of a service under `lib/managers/`.
String ocptBudgetExportAmountLabel(int cents, String currencyCode) =>
    NumberFormat.simpleCurrency(name: currencyCode).format(cents / 100);

/// [quantityMilli] written back as the figure somebody typed — `1500` is `1.5`, `1484000` is
/// `1,484` — mirroring `ocptBudgetQuantityLabel`'s own formula for the reason
/// [ocptBudgetExportAmountLabel]'s own doc comment gives.
String ocptBudgetExportQuantityLabel(int quantityMilli) =>
    NumberFormat("#,##0.###").format(quantityMilli / 1000);

/// The moment [exportDate] was produced, as `yyyy-MM-dd HH:mm` — deliberately not locale-formatted,
/// mirroring `ocptScheduleGeneratedAtStamp`'s own reasoning: a stamp two documents of the same run
/// disagree about would be worse than one that reads the same in every language this app ships in.
String ocptBudgetExportGeneratedAtStamp(DateTime exportDate) =>
    "${exportDate.year.toString().padLeft(4, '0')}-${exportDate.month.toString().padLeft(2, '0')}-"
    "${exportDate.day.toString().padLeft(2, '0')} ${exportDate.hour.toString().padLeft(2, '0')}:"
    "${exportDate.minute.toString().padLeft(2, '0')}";

/// [total]'s own amount, formatted through [ocptBudgetExportAmountLabel] — or, whenever
/// [OcptBudgetCoveredTotal.isComplete] is false, [coverageReadOutTemplate] with its own
/// `{amount}`/`{coveredCount}`/`{totalCount}` placeholders filled in, mirroring
/// `tr.budgetCostTrackingCoverageReadOut`'s own reading: the amount that figure covers is never
/// printed standing in for the rows it does not, and the reader is told exactly how many of them
/// that is.
String ocptBudgetExportCoveredAmountText({
  required OcptBudgetCoveredTotal total,
  required String currencyCode,
  required String coverageReadOutTemplate,
}) {
  final amountText = ocptBudgetExportAmountLabel(total.amountCents, currencyCode);
  if (total.isComplete) {
    return amountText;
  }

  return coverageReadOutTemplate
      .replaceAll("{amount}", amountText)
      .replaceAll("{coveredCount}", "${total.coveredLineCount}")
      .replaceAll("{totalCount}", "${total.lineCount}");
}

/// The dashboard's own three-way verdict over [balance] — "no quote yet" for a quote with no line
/// at all, "balanced" once the financing plan covers it, or [shortfallMessageTemplate] with its own
/// `{amount}` placeholder filled in with how far short it falls — mirroring
/// `OcptBudgetDashboard`'s own reading of `ocptBudgetNeedsResourcesBalanceOf`: a plain
/// `resources >= needs` reading would answer "balanced" for a project that has recorded nothing,
/// which this mode refuses everywhere else.
String ocptBudgetExportBalanceVerdict({
  required OcptBudgetNeedsResourcesBalance balance,
  required String noQuoteMessage,
  required String balancedMessage,
  required String shortfallMessageTemplate,
  required String currencyCode,
}) {
  if (balance.needs.lineCount == 0) {
    return noQuoteMessage;
  }
  if (balance.isBalanced) {
    return balancedMessage;
  }

  return shortfallMessageTemplate.replaceAll(
    "{amount}",
    ocptBudgetExportAmountLabel(-balance.differenceCents, currencyCode),
  );
}
