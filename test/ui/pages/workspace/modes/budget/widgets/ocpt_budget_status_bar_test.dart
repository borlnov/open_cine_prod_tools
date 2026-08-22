// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a box wide
/// enough that nothing degrades.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, child: child)),
);

void main() {
  testWidgets("names the trailing figure as the quote, whatever it is", (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OcptBudgetStatusBar(posteCount: 10, lineCount: 24, quotedTotalCents: 1996000, currencyCode: "EUR"),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetStatusBar)));
    expect(
      find.text(tr.budgetStatsQuoteTotal(ocptBudgetAmountLabel(1996000, "EUR"))),
      findsOneWidget,
    );
    // A bare, unlabelled figure is never drawn on its own.
    expect(find.text(ocptBudgetAmountLabel(1996000, "EUR")), findsNothing);
  });

  testWidgets("still names the figure on a project whose quote is empty", (tester) async {
    await tester.pumpWidget(
      _wrap(const OcptBudgetStatusBar(posteCount: 0, lineCount: 0, quotedTotalCents: 0, currencyCode: "EUR")),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetStatusBar)));
    expect(find.text(tr.budgetStatsQuoteTotal(ocptBudgetAmountLabel(0, "EUR"))), findsOneWidget);
  });
}
