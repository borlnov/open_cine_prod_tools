// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that the whole dashboard is drawn with no scroll needed to find a card.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1200, height: 900, child: child)),
);

/// Builds a quote line quoted at [amountCents] (a single unit at that price), everything else
/// neutral.
OcptBudgetLine _buildLine({
  required String id,
  required String posteId,
  required int amountCents,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: "Line $id",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  elementId: null,
  notes: "",
  sortKey: "a0",
);

/// Builds a poste quoted at [quotedAmountCents] (a single line carrying that whole amount),
/// everything else neutral.
OcptBudgetPoste _buildPoste({
  required String id,
  String label = "Camera",
  required int quotedAmountCents,
}) => OcptBudgetPoste(
  id: id,
  code: "1",
  label: label,
  simpleLabel: null,
  sortKey: "a0",
  lines: [_buildLine(id: "$id-line", posteId: id, amountCents: quotedAmountCents)],
);

/// The zero-everything cash totals every test not concerned with the balance itself starts from.
const _zeroCashTotals = OcptBudgetCashTotals(
  debitCents: 0,
  creditCents: 0,
  coveredEntryCount: 0,
  entryCount: 0,
);

/// Pumps [OcptBudgetDashboard] with the neutral defaults every test but the one it varies wants.
Future<Tr> _pumpDashboard(
  WidgetTester tester, {
  required List<OcptBudgetPoste> postes,
  OcptBudgetCashTotals cashTotals = _zeroCashTotals,
  Map<String, OcptBudgetCoveredTotal> paidByPosteId = const {},
  Map<String, OcptBudgetCoveredTotal> committedByPosteId = const {},
  List<OcptBudgetAlert> alerts = const [],
  ValueChanged<String>? onPosteSelected,
  ValueChanged<String>? onPosteAlertActionRequested,
  VoidCallback? onCashAlertActionRequested,
}) async {
  await tester.pumpWidget(
    _wrap(
      OcptBudgetDashboard(
        postes: postes,
        taxBasis: OcptBudgetTaxBasis.includingTax,
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
        cashTotals: cashTotals,
        paidByPosteId: paidByPosteId,
        committedByPosteId: committedByPosteId,
        alerts: alerts,
        onPosteSelected: onPosteSelected ?? (_) {},
        onPosteAlertActionRequested: onPosteAlertActionRequested ?? (_) {},
        onCashAlertActionRequested: onCashAlertActionRequested ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  return Tr.of(tester.element(find.byType(OcptBudgetDashboard)));
}

void main() {
  group("the KPI row", () {
    testWidgets("prints the cash balance, paid and committed KPIs", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 3000,
          creditCents: 8000,
          coveredEntryCount: 2,
          entryCount: 2,
        ),
        paidByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 3000,
            coveredLineCount: 1,
            lineCount: 1,
          ),
        },
        committedByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 4000,
            coveredLineCount: 1,
            lineCount: 1,
          ),
        },
      );

      expect(find.text(tr.budgetDashboardCashBalanceLabel.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsOneWidget);
      expect(find.text(tr.budgetDashboardPaidLabel.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(3000, "EUR")), findsOneWidget);
      expect(find.text(tr.budgetDashboardCommittedLabel.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(4000, "EUR")), findsOneWidget);
    });

    testWidgets("the cash-balance KPI shows a coverage caption while an entry cannot be read", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 1000,
          creditCents: 1000,
          coveredEntryCount: 1,
          entryCount: 2,
        ),
      );

      expect(find.text(tr.budgetDashboardCoverageCaption(1, 2)), findsOneWidget);
    });

    testWidgets("no empty section is drawn for a project raising neither alert", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      await _pumpDashboard(tester, postes: [poste]);

      expect(find.byType(Container), findsNothing);
    });
  });

  group("a poste over its quote", () {
    testWidgets("draws its own alert card, naming the poste and by how much it is over", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final alert = const OcptBudgetPosteOverQuoteAlert(
        posteId: "poste-1",
        quotedAmountCents: 10000,
        paidCents: 7000,
        committedCents: 5000,
        varianceCents: 2000,
      );

      final tr = await _pumpDashboard(tester, postes: [poste], alerts: [alert]);

      expect(find.text(tr.budgetDashboardPosteOverQuoteAlertTitle), findsOneWidget);
      expect(
        find.text(
          tr.budgetDashboardPosteOverQuoteAlertMessage(
            "Camera",
            ocptBudgetAmountLabel(12000, "EUR"),
            ocptBudgetAmountLabel(10000, "EUR"),
            ocptBudgetAmountLabel(2000, "EUR"),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets("its own action selects the poste and switches the centre view", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final alert = const OcptBudgetPosteOverQuoteAlert(
        posteId: "poste-1",
        quotedAmountCents: 10000,
        paidCents: 12000,
        committedCents: 0,
        varianceCents: 2000,
      );

      String? selectedPosteId;
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        alerts: [alert],
        onPosteAlertActionRequested: (posteId) => selectedPosteId = posteId,
      );

      await tester.tap(find.text(tr.budgetDashboardPosteOverQuoteAlertAction));
      await tester.pumpAndSettle();

      expect(selectedPosteId, "poste-1");
    });
  });

  group("the cash projection going negative", () {
    testWidgets("a dated instalment prints the balance, the date and the amount falling due", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final alert = OcptBudgetCashProjectionNegativeAlert(
        balanceCents: 5000,
        dueDate: DateTime(2026, 3, 15),
        fallingDueCents: 8000,
        balanceAfterCents: -3000,
      );

      final tr = await _pumpDashboard(tester, postes: [poste], alerts: [alert]);

      expect(find.text(tr.budgetDashboardCashNegativeAlertTitle), findsOneWidget);
      expect(find.textContaining(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      expect(find.textContaining(ocptBudgetAmountLabel(8000, "EUR")), findsWidgets);
    });

    testWidgets("an undated instalment words the message differently, never an empty date", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      const alert = OcptBudgetCashProjectionNegativeAlert(
        balanceCents: 1000,
        dueDate: null,
        fallingDueCents: 6000,
        balanceAfterCents: -5000,
      );

      final tr = await _pumpDashboard(tester, postes: [poste], alerts: [alert]);

      expect(
        find.text(
          tr.budgetDashboardCashNegativeAlertMessageUndated(
            ocptBudgetAmountLabel(1000, "EUR"),
            ocptBudgetAmountLabel(6000, "EUR"),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets("its own action switches the centre view, with no poste to select", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      const alert = OcptBudgetCashProjectionNegativeAlert(
        balanceCents: 1000,
        dueDate: null,
        fallingDueCents: 6000,
        balanceAfterCents: -5000,
      );

      var wasRequested = false;
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        alerts: [alert],
        onCashAlertActionRequested: () => wasRequested = true,
      );

      await tester.tap(find.text(tr.budgetDashboardCashNegativeAlertAction));
      await tester.pumpAndSettle();

      expect(wasRequested, isTrue);
    });
  });
}
