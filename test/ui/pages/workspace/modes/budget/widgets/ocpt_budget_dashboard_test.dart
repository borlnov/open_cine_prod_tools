// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
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

/// Builds a quote line quoted at [amountCents] (a single unit at that price), tax-inclusive with no
/// override by default — [isTaxInclusive]`: false` and no [vatRateBasisPoints] is what a test needs
/// to make this line's own tax-inclusive reading unknown, everything else neutral.
OcptBudgetLine _buildLine({
  required String id,
  required String posteId,
  required int amountCents,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: "Line $id",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(
    amountCents: amountCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  elementId: null,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// A minimal financing resource, everything but what each test actually varies neutral — mirrors
/// `ocpt_budget_financing_test.dart`'s own `_resource`.
OcptBudgetResource _resource({
  required String id,
  OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.subsidy,
  required int amountCents,
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  personId: null,
  label: "Resource $id",
  amountCents: amountCents,
  status: OcptBudgetResourceStatus.pending,
  isReimbursable: false,
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
  estimateToCompleteCents: null,
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

/// The zero-everything, fully-covered total every test not concerned with off-quote spending
/// starts from.
const _zeroCoveredTotal = OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0);

/// Pumps [OcptBudgetDashboard] with the neutral defaults every test but the one it varies wants.
Future<Tr> _pumpDashboard(
  WidgetTester tester, {
  required List<OcptBudgetPoste> postes,
  OcptBudgetTaxBasis taxBasis = OcptBudgetTaxBasis.includingTax,
  OcptBudgetCashTotals cashTotals = _zeroCashTotals,
  Map<String, OcptBudgetCoveredTotal> paidByPosteId = const {},
  OcptBudgetCoveredTotal offQuotePaidTotal = _zeroCoveredTotal,
  Map<String, OcptBudgetCoveredTotal> committedByPosteId = const {},
  List<OcptBudgetAlert> alerts = const [],
  List<OcptBudgetResource> resources = const [],
  ValueChanged<String>? onPosteOpened,
  VoidCallback? onCashAlertActionRequested,
}) async {
  await tester.pumpWidget(
    _wrap(
      OcptBudgetDashboard(
        postes: postes,
        taxBasis: taxBasis,
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
        cashTotals: cashTotals,
        paidByPosteId: paidByPosteId,
        offQuotePaidTotal: offQuotePaidTotal,
        committedByPosteId: committedByPosteId,
        alerts: alerts,
        resources: resources,
        onPosteOpened: onPosteOpened ?? (_) {},
        onCashAlertActionRequested: onCashAlertActionRequested ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  return Tr.of(tester.element(find.byType(OcptBudgetDashboard)));
}

void main() {
  group("the Devis total tile", () {
    testWidgets("reads the quote's own total and how many postes it holds", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(tester, postes: [poste]);

      expect(find.text(tr.budgetDashboardQuotedTotalLabel.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(10000, "EUR")), findsOneWidget);
      expect(find.text(tr.budgetStatsPostes(1)), findsOneWidget);
    });

    testWidgets("shows the coverage read-out instead of the poste count while a line lacks a rate", (
      tester,
    ) async {
      final uncoveredLine = _buildLine(
        id: "poste-1-line",
        posteId: "poste-1",
        amountCents: 10000,
        isTaxInclusive: false,
      );
      final poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Camera",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a0",
        lines: [uncoveredLine],
      );

      final tr = await _pumpDashboard(tester, postes: [poste]);

      expect(find.text(tr.budgetDashboardCoverageCaption(0, 1)), findsOneWidget);
      expect(find.text(tr.budgetStatsPostes(1)), findsNothing);
    });
  });

  group("the Financement tile", () {
    testWidgets("reads the resources total and how much of it is in kind, whatever each resource's own status", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        resources: [
          _resource(id: "r1", amountCents: 5000),
          _resource(id: "r2", groupKind: OcptBudgetResourceGroupKind.inKind, amountCents: 2000),
        ],
      );

      expect(find.text(tr.budgetDashboardFinancingLabel.toUpperCase()), findsOneWidget);
      // The balance card's own "Resources" line reads the very same total, so this amount is drawn
      // twice on screen — see `_OcptDashboardBalanceBar`'s own doc comment.
      expect(find.text(ocptBudgetAmountLabel(7000, "EUR")), findsWidgets);
      expect(
        find.text(tr.budgetDashboardResourcesInKindCaption(ocptBudgetAmountLabel(2000, "EUR"))),
        findsOneWidget,
      );
    });
  });

  group("the Dépensé tile", () {
    testWidgets("folds off-quote spending in with the per-poste total", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        paidByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 3000,
            coveredLineCount: 1,
            lineCount: 1,
          ),
        },
        offQuotePaidTotal: const OcptBudgetCoveredTotal(
          amountCents: 500,
          coveredLineCount: 1,
          lineCount: 1,
        ),
      );

      expect(find.text(tr.budgetDashboardSpentLabel.toUpperCase()), findsOneWidget);
      // 30.00 € against the poste plus 5.00 € off quote — what the cash journal would agree left
      // the account, not only what priced a poste.
      expect(find.text(ocptBudgetAmountLabel(3500, "EUR")), findsOneWidget);
    });

    testWidgets("its own hint reads the share of the quote it represents, off-quote spending included", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        paidByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 3000,
            coveredLineCount: 1,
            lineCount: 1,
          ),
        },
      );

      expect(find.text(tr.budgetDashboardSpentShareCaption(30)), findsOneWidget);
    });

    testWidgets("the coverage read-out wins over the percentage while a row cannot be read", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        paidByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 3000,
            coveredLineCount: 0,
            lineCount: 1,
          ),
        },
      );

      expect(find.text(tr.budgetDashboardCoverageCaption(0, 1)), findsOneWidget);
      expect(find.textContaining("%"), findsNothing);
    });

    testWidgets("prints no percentage at all rather than dividing by a zero-total quote", (
      tester,
    ) async {
      final poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Camera",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a0",
        lines: [_buildLine(id: "poste-1-line", posteId: "poste-1", amountCents: 0)],
      );

      await _pumpDashboard(
        tester,
        postes: [poste],
        paidByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 3000,
            coveredLineCount: 1,
            lineCount: 1,
          ),
        },
      );

      // Every row is covered and the quote totals zero — the percentage is withheld whole, not
      // printed as `0 %` or divided by zero.
      expect(find.textContaining("%"), findsNothing);
    });
  });

  group("the Solde en banque tile", () {
    testWidgets("prints the cash balance", (tester) async {
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
      );

      expect(find.text(tr.budgetDashboardCashBalanceLabel.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsOneWidget);
    });

    testWidgets("its own hint names what is committed once every entry can be read", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        committedByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 4000,
            coveredLineCount: 1,
            lineCount: 1,
          ),
        },
      );

      expect(
        find.text(tr.budgetDashboardCommittedCaption(ocptBudgetAmountLabel(4000, "EUR"))),
        findsOneWidget,
      );
    });

    testWidgets("the coverage read-out wins over the committed hint while an entry cannot be read", (
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
        committedByPosteId: {
          "poste-1": const OcptBudgetCoveredTotal(
            amountCents: 4000,
            coveredLineCount: 1,
            lineCount: 1,
          ),
        },
      );

      expect(find.text(tr.budgetDashboardCoverageCaption(1, 2)), findsOneWidget);
      expect(
        find.text(tr.budgetDashboardCommittedCaption(ocptBudgetAmountLabel(4000, "EUR"))),
        findsNothing,
      );
    });
  });

  group("the balance card", () {
    testWidgets("shows its own title", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(tester, postes: [poste]);

      expect(find.text(tr.budgetDashboardBalanceTitle.toUpperCase()), findsOneWidget);
    });

    testWidgets("resources exceeding the quote read as balanced", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        resources: [_resource(id: "r1", amountCents: 15000)],
      );

      expect(find.text(tr.budgetDashboardBalanceBalancedMessage), findsOneWidget);
    });

    testWidgets("a poste with no quote line at all claims no verdict either way", (tester) async {
      // A plain `resources >= needs` reading would answer "balanced" here, declaring the financing
      // plan sufficient against a quote nobody has begun — a claim the data cannot support.
      final tr = await _pumpDashboard(
        tester,
        postes: const [
          OcptBudgetPoste(
            id: "poste-1",
            code: "1",
            label: "Camera",
            simpleLabel: null,
            estimateToCompleteCents: null,
            sortKey: "a0",
            lines: [],
          ),
        ],
        resources: [_resource(id: "r1", amountCents: 15000)],
      );

      expect(find.text(tr.budgetDashboardBalanceNoQuoteMessage), findsOneWidget);
      expect(find.text(tr.budgetDashboardBalanceBalancedMessage), findsNothing);
    });

    testWidgets("a project with no resource and no quote claims nothing either", (tester) async {
      final tr = await _pumpDashboard(
        tester,
        postes: const [
          OcptBudgetPoste(
            id: "poste-1",
            code: "1",
            label: "Camera",
            simpleLabel: null,
            estimateToCompleteCents: null,
            sortKey: "a0",
            lines: [],
          ),
        ],
      );

      expect(find.text(tr.budgetDashboardBalanceNoQuoteMessage), findsOneWidget);
      expect(find.text(tr.budgetDashboardBalanceBalancedMessage), findsNothing);
    });

    testWidgets("resources falling short of the quote say by how much, in the error colour", (
      tester,
    ) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        resources: [_resource(id: "r1", amountCents: 4000)],
      );

      final finder = find.text(
        tr.budgetDashboardBalanceShortfallMessage(ocptBudgetAmountLabel(6000, "EUR")),
      );
      expect(finder, findsOneWidget);
      final style = tester.widget<Text>(finder).style;
      expect(style?.color, Theme.of(tester.element(finder)).colorScheme.error);
    });

    testWidgets("the needs figure prints its own coverage read-out while a line lacks a rate", (
      tester,
    ) async {
      final uncoveredLine = _buildLine(
        id: "poste-1-line",
        posteId: "poste-1",
        amountCents: 10000,
        isTaxInclusive: false,
      );
      final poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Camera",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a0",
        lines: [uncoveredLine],
      );

      final tr = await _pumpDashboard(tester, postes: [poste]);

      expect(
        find.text(
          "${tr.budgetDashboardBalanceNeedsLabel} "
          "${tr.budgetDashboardBalanceCoverageReadOut(ocptBudgetAmountLabel(0, "EUR"), 0, 1)}",
        ),
        findsOneWidget,
      );
    });

    testWidgets("the coverage read-out drops once every line carries a known rate", (tester) async {
      // The very same poste as the previous test, its own line typed tax-inclusive this time (the
      // default `_buildLine` reads under), which needs no rate at all to answer the tax-inclusive
      // reading the balance card always reads under.
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);

      final tr = await _pumpDashboard(tester, postes: [poste]);

      expect(
        find.text("${tr.budgetDashboardBalanceNeedsLabel} ${ocptBudgetAmountLabel(10000, "EUR")}"),
        findsOneWidget,
      );
    });

    testWidgets("reads tax-inclusive regardless of the header's basis toggle", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 12345);

      final tr = await _pumpDashboard(
        tester,
        postes: [poste],
        taxBasis: OcptBudgetTaxBasis.excludingTax,
      );

      // The Devis total tile follows the header's own (excluding-tax) basis and cannot answer this
      // line's own tax-inclusive amount, so only the balance card's own needs line can be showing
      // it, tax-inclusive always.
      expect(
        find.text("${tr.budgetDashboardBalanceNeedsLabel} ${ocptBudgetAmountLabel(12345, "EUR")}"),
        findsOneWidget,
      );
    });
  });

  group("the alerts card", () {
    testWidgets("draws no card at all for a project raising no alert", (tester) async {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);
      final tr = await _pumpDashboard(tester, postes: [poste]);

      expect(find.text(tr.budgetDashboardAlertsSectionTitle), findsNothing);
    });

    testWidgets("a poste over its quote draws its own badge, message and the variance printed negative", (
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

      expect(find.text(tr.budgetDashboardAlertsSectionTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardOverrunBadge), findsOneWidget);
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
      expect(find.text(ocptBudgetAmountLabel(-2000, "EUR")), findsOneWidget);
    });

    testWidgets("its own row selects the poste and switches the centre view", (tester) async {
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
        onPosteOpened: (posteId) => selectedPosteId = posteId,
      );

      // No button — the row itself, tapped through its own badge, is the click target.
      await tester.tap(find.text(tr.budgetDashboardOverrunBadge));
      await tester.pumpAndSettle();

      expect(selectedPosteId, "poste-1");
    });

    testWidgets("a dated cash instalment prints the balance, the date and the amount falling due", (
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

      expect(find.text(tr.budgetDashboardCashAlertBadge), findsOneWidget);
      expect(find.textContaining(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      expect(find.textContaining(ocptBudgetAmountLabel(8000, "EUR")), findsWidgets);
    });

    testWidgets("an undated cash instalment words the message differently, never an empty date", (
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

    testWidgets("its own row switches the centre view, with no poste to select", (tester) async {
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

      await tester.tap(find.text(tr.budgetDashboardCashAlertBadge));
      await tester.pumpAndSettle();

      expect(wasRequested, isTrue);
    });
  });

  group("the empty state", () {
    testWidgets("answers only for a project holding nothing this page reads", (tester) async {
      final tr = await _pumpDashboard(tester, postes: const []);

      expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
      expect(find.text(tr.budgetDashboardEmptyHint), findsOneWidget);
    });

    testWidgets("a production that recorded its financing first still reads it", (tester) async {
      // Financing before a quote is an ordinary order of work, and the page that summarises the
      // project must not hide what has already been typed behind an invitation to start elsewhere.
      final tr = await _pumpDashboard(
        tester,
        postes: const [],
        resources: [_resource(id: "r1", amountCents: 620000)],
      );

      expect(find.byType(OcptWorkspaceEmptyMode), findsNothing);
      expect(find.text(tr.budgetDashboardFinancingLabel.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(620000, "EUR")), findsOneWidget);
      expect(
        find.text(
          "${tr.budgetDashboardBalanceResourcesLabel} ${ocptBudgetAmountLabel(620000, "EUR")}",
        ),
        findsOneWidget,
      );

      // And the balance band says it has no quote to measure that plan against, rather than
      // declaring the plan sufficient against a quote nobody has begun.
      expect(find.text(tr.budgetDashboardBalanceNoQuoteMessage), findsOneWidget);
    });

    testWidgets("a project with movements but no quote still reads its balance", (tester) async {
      final tr = await _pumpDashboard(
        tester,
        postes: const [],
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 800000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      expect(find.byType(OcptWorkspaceEmptyMode), findsNothing);
      expect(find.text(tr.budgetDashboardCashBalanceLabel.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(800000, "EUR")), findsOneWidget);
    });
  });
}
