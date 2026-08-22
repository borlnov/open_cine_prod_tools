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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a
/// [width]×[height] band — wide enough by default that every column of the table is drawn with
/// no horizontal scroll at all; a test of the scrolling pane itself passes a narrower [width].
Widget _wrap(Widget child, {double width = 1400, double height = 600}) =>
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Scaffold(
        body: SizedBox(width: width, height: height, child: child),
      ),
    );

/// The scrolling pane's own horizontal [SingleChildScrollView] — the vertical one, wrapping the
/// whole two-pane [Row], is the only other [SingleChildScrollView] in the tree, so filtering on
/// [Axis.horizontal] picks this one out uniquely.
final Finder _amountsPaneScrollFinder = find.byWidgetPredicate(
  (widget) =>
      widget is SingleChildScrollView &&
      widget.scrollDirection == Axis.horizontal,
);

/// A quote line priced at 10.00 €, tax-inclusive, whose rate is known only when
/// `vatRateBasisPoints` is given.
OcptBudgetLine _line({
  required String id,
  required String posteId,
  int? vatRateBasisPoints,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: "Line $id",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(
    amountCents: 1000,
    isTaxInclusive: true,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  elementId: null,
  notes: "",
  sortKey: "a0",
);

void main() {
  testWidgets(
    "the detailed header shows the poste code; the simplified one hides it and uses the "
    "simple label",
    (tester) async {
      final poste = OcptBudgetPoste(
        id: "poste-1",
        code: "7",
        label: "Technical equipment",
        simpleLabel: "Camera and lighting gear",
        sortKey: "a0",
        lines: [
          _line(id: "line-1", posteId: "poste-1", vatRateBasisPoints: 2000),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [poste],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      expect(find.text("7"), findsOneWidget);
      expect(find.text("Technical equipment"), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [poste],
            selectedPosteId: null,
            isSimplified: true,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      expect(find.text("7"), findsNothing);
      expect(find.text("Camera and lighting gear"), findsOneWidget);
    },
  );

  testWidgets(
    "the total row reports how many postes its coverage reaches while a line carries no known "
    "rate, under the excluding-tax basis",
    (tester) async {
      final postes = [
        OcptBudgetPoste(
          id: "poste-1",
          code: "1",
          label: "Covered",
          simpleLabel: null,
          sortKey: "a0",
          lines: [
            _line(id: "line-1", posteId: "poste-1", vatRateBasisPoints: 2000),
          ],
        ),
        OcptBudgetPoste(
          id: "poste-2",
          code: "2",
          label: "Uncovered",
          simpleLabel: null,
          sortKey: "a1",
          // No rate on this line, and none on the project either: its excluding-tax figure is
          // unknown, so this poste never counts as covered under that basis.
          lines: [_line(id: "line-2", posteId: "poste-2")],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: postes,
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.excludingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      // Poste 1's own 10.00 € tax-inclusive line, at 20 %, reads 8.33 € excluding tax
      // (1000 × 10000 / 12000, rounded) — the only poste this basis actually covers.
      final coveredAmount = ocptBudgetAmountLabel(833, "EUR");
      expect(
        find.text(tr.budgetCostTrackingCoverageReadOut(coveredAmount, 1, 2)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "withholds the creation footer and every row's own ⋮ menu while isReadOnly",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Poste one",
        simpleLabel: null,
        sortKey: "a0",
        lines: [],
      );

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [poste],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: true,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetPosteCreationAction), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    },
  );

  testWidgets(
    "the poste label stays visible after the amounts pane is scrolled to its own far right",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Artistic rights and costumes",
        simpleLabel: null,
        sortKey: "a0",
        lines: [],
      );

      // Narrower than the pinned pane's own floor (44 + 220) plus the six fixed-width amount
      // columns and the menu column (108 × 6 + 36) combined — the regression this table's split
      // into two panes exists to fix: before it, a table this narrow scrolled the `Poste` column
      // itself out of view along with the amounts.
      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [poste],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
          width: 620,
        ),
      );

      expect(_amountsPaneScrollFinder, findsOneWidget);
      await tester.drag(_amountsPaneScrollFinder, const Offset(-2000, 0));
      await tester.pumpAndSettle();

      expect(find.text("Artistic rights and costumes"), findsOneWidget);
    },
  );

  testWidgets(
    "selecting a poste highlights it in both the pinned pane and the scrolling pane",
    (tester) async {
      const postes = [
        OcptBudgetPoste(
          id: "poste-1",
          code: "1",
          label: "Poste one",
          simpleLabel: null,
          sortKey: "a0",
          lines: [],
        ),
        OcptBudgetPoste(
          id: "poste-2",
          code: "2",
          label: "Poste two",
          simpleLabel: null,
          sortKey: "a1",
          lines: [],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: postes,
            selectedPosteId: "poste-1",
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      // One `ColoredBox` per pane per row (`_OcptCostTrackingIdentityRow`,
      // `_OcptCostTrackingAmountsRow`) — exactly two of the four painted here (two postes, two
      // panes) leave the selected poste's own transparent default.
      final highlightedCount = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color != Colors.transparent)
          .length;

      expect(highlightedCount, 2);
    },
  );

  testWidgets(
    "simplified mode drops the N° column and narrows the pinned pane by that column's own width",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Poste one",
        simpleLabel: "Simple",
        sortKey: "a0",
        lines: [],
      );

      Widget buildTable({required bool isSimplified}) => OcptBudgetCostTracking(
        postes: [poste],
        selectedPosteId: null,
        isSimplified: isSimplified,
        taxBasis: OcptBudgetTaxBasis.includingTax,
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
        paidByPosteId: const {},
        committedCentsOf: (_) => 0,
        offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        isReadOnly: false,
        onPosteSelected: (_) {},
        onPosteCreationRequested: () {},
        onPosteReorderRequested: (_, {required moveUp}) {},
        onPosteDeletionRequested: (_) {},
      );

      // Narrow enough that the `Poste` column sits at its own floor in both modes, so the pinned
      // pane's own width changes by exactly the `N°` column's width rather than the `Poste`
      // column silently absorbing the difference (which it does the moment there is room to
      // spare).
      await tester.pumpWidget(
        _wrap(buildTable(isSimplified: false), width: 620),
      );
      final detailedAmountsPaneLeftEdge = tester
          .getTopLeft(_amountsPaneScrollFinder)
          .dx;

      await tester.pumpWidget(
        _wrap(buildTable(isSimplified: true), width: 620),
      );
      final simplifiedAmountsPaneLeftEdge = tester
          .getTopLeft(_amountsPaneScrollFinder)
          .dx;

      expect(find.text("1"), findsNothing);
      expect(find.text("Simple"), findsOneWidget);
      // 44 px — `_ocptCostTrackingNumberColumnWidth` in the widget file, the `N°` column's own
      // fixed width.
      expect(detailedAmountsPaneLeftEdge - simplifiedAmountsPaneLeftEdge, 44);
    },
  );

  /// A poste quoted at 50.00 € (one line: 1 × 50.00 €), so `Consumed` reads a real percentage
  /// rather than the em dash whatever is paid or committed against it.
  OcptBudgetPoste quotedPoste() => const OcptBudgetPoste(
    id: "poste-1",
    code: "1",
    label: "Poste one",
    simpleLabel: null,
    sortKey: "a0",
    lines: [
      OcptBudgetLine(
        id: "line-1",
        posteId: "poste-1",
        label: "Line one",
        quantityMilli: 1000,
        unit: "u",
        unitPrice: OcptMoney(
          amountCents: 5000,
          isTaxInclusive: true,
          vatRateBasisPoints: null,
        ),
        elementId: null,
        notes: "",
        sortKey: "a0",
      ),
    ],
  );

  testWidgets(
    "a poste whose entries have been paid shows the real figures for Paid, Committed, Remaining "
    "and Variance",
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [quotedPoste()],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: {
              "poste-1": const OcptBudgetCoveredTotal(
                amountCents: 1200,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            committedCentsOf: (_) => 300,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      // Quoted 50.00 €, Paid 12.00 €, Committed 3.00 €, Remaining 35.00 € (50 - 12 - 3), Variance
      // -35.00 € (12 + 3 - 50), Consumed 30 % ((12 + 3) / 50) — none of them the em dash. The
      // single poste's own Paid figure is also the whole table's grand Paid total (no off-quote
      // spending here), so 12.00 € is drawn twice: this poste's own row, and the total row.
      expect(find.text(ocptBudgetAmountLabel(1200, "EUR")), findsNWidgets(2));
      expect(find.text(ocptBudgetAmountLabel(300, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(3500, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(-3500, "EUR")), findsOneWidget);
      expect(find.text("30 %"), findsOneWidget);
      // The total row's own `Committed`, `Remaining`, `Variance` and `Consumed` cells always print
      // the em dash (there is no grand reading for any of them — the total row's own class doc
      // comment argues why); this poste's own row contributes none of its own.
      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(4));
    },
  );

  testWidgets(
    "a poste with no entry or commitment against it shows zero rather than a hole for Paid and "
    "Committed",
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [quotedPoste()],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      // Paid and Committed both read a real zero — nothing having moved against this poste is a
      // known fact now that the journal exists, not a stand-in for an unknown figure. The grand
      // Paid total in the total row is the very same real zero, once more.
      expect(find.text(ocptBudgetAmountLabel(0, "EUR")), findsNWidgets(3));
      // Only the total row's own `Committed`, `Remaining`, `Variance` and `Consumed` cells print
      // the em dash here (see the previous test's own comment) — this poste's own row contributes
      // none.
      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(4));
    },
  );

  testWidgets(
    "the Consumed column reads the em dash for a poste carrying no quote at all",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "No quote",
        simpleLabel: null,
        sortKey: "a0",
        lines: [],
      );

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [poste],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      // Five dashes: this poste's own Consumed cell (no quote to divide by), plus the total row's
      // own `Committed`, `Remaining`, `Variance` and `Consumed` cells (see the earlier tests' own
      // comment on that row). The total row's own `Quote` and `Paid` cells both read a real
      // 0.00 € here (an empty quote and no off-quote spending), not the em dash.
      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(5));
    },
  );

  group("the off-quote row", () {
    /// 25.00 € worth of debits naming no poste at all, fully covered.
    const offQuoteTotal = OcptBudgetCoveredTotal(amountCents: 2500, coveredLineCount: 1, lineCount: 1);

    testWidgets("is drawn between the last poste and the Total row while there is off-quote spending", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [quotedPoste()],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: offQuoteTotal,
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetCostTrackingOffQuoteLabel), findsOneWidget);
      // Its own Paid cell reads the off-quote total, and, since no poste itself was paid, the
      // total row's own grand Paid figure reads the very same amount — drawn twice.
      expect(find.text(ocptBudgetAmountLabel(2500, "EUR")), findsNWidgets(2));
    });

    testWidgets("is absent while there is no off-quote spending at all", (tester) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [quotedPoste()],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: const {},
            committedCentsOf: (_) => 0,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetCostTrackingOffQuoteLabel), findsNothing);
    });

    testWidgets(
      "carries no ⋮ menu, prints the em dash in every column it has no reading for, and a tap on "
      "it does not select a poste",
      (tester) async {
        String? selectedPosteId;

        await tester.pumpWidget(
          _wrap(
            OcptBudgetCostTracking(
              postes: [quotedPoste()],
              selectedPosteId: null,
              isSimplified: false,
              taxBasis: OcptBudgetTaxBasis.includingTax,
              defaultVatRateBasisPoints: null,
              currencyCode: "EUR",
              paidByPosteId: const {},
              committedCentsOf: (_) => 0,
              offQuoteTotal: offQuoteTotal,
              isReadOnly: false,
              onPosteSelected: (posteId) => selectedPosteId = posteId,
              onPosteCreationRequested: () {},
              onPosteReorderRequested: (_, {required moveUp}) {},
              onPosteDeletionRequested: (_) {},
            ),
          ),
        );

        final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
        // Exactly one ⋮ menu on screen: the single poste's own — none for the off-quote row.
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);

        // Quote, Committed, Remaining, Variance, Consumed: five em dashes on the off-quote row's
        // own line, its `Paid` cell the one cell that is not one of them.
        expect(find.text(ocptBudgetEmptyValue), findsWidgets);

        await tester.tap(find.text(tr.budgetCostTrackingOffQuoteLabel));
        await tester.pumpAndSettle();

        expect(selectedPosteId, isNull);
      },
    );
  });
}
