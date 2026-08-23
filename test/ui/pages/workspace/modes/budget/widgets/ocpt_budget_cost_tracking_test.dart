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

/// A quote line priced at [amountCents] (10.00 € by default), tax-inclusive, whose rate is known
/// only when `vatRateBasisPoints` is given.
OcptBudgetLine _line({
  required String id,
  required String posteId,
  int? vatRateBasisPoints,
  int amountCents = 1000,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: "Line $id",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(
    amountCents: amountCents,
    isTaxInclusive: true,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  elementId: null,
  provisionKey: null,
  provisionDigest: null,
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
        estimateToCompleteCents: null,
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
          estimateToCompleteCents: null,
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
          estimateToCompleteCents: null,
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
        estimateToCompleteCents: null,
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
        estimateToCompleteCents: null,
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
          estimateToCompleteCents: null,
          sortKey: "a0",
          lines: [],
        ),
        OcptBudgetPoste(
          id: "poste-2",
          code: "2",
          label: "Poste two",
          simpleLabel: null,
          estimateToCompleteCents: null,
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
        estimateToCompleteCents: null,
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
    estimateToCompleteCents: null,
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
        provisionKey: null,
        provisionDigest: null,
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
      // 35.00 € is drawn three times: Remaining reads it, so does the derived Estimate to
      // complete beside it (`max(0, Remaining)`, the poste's own `estimateToCompleteCents` being
      // null here — the two coincide whenever a poste isn't over its own quote), and so does the
      // total row's own grand Estimate to complete, this single poste being the whole table.
      expect(find.text(ocptBudgetAmountLabel(3500, "EUR")), findsNWidgets(3));
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
        estimateToCompleteCents: null,
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
      // comment on that row). The total row's own `Quote`, `Paid`, `Estimate to complete` and
      // `Final cost` cells all read a real 0.00 € here (an empty quote, no off-quote spending, and
      // `max(0, 0 - 0 - 0)` is zero rather than nothing), not the em dash — this poste's own
      // Estimate to complete and Final cost cells read the very same real zero.
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

        // Quote, Committed, Remaining, Estimate to complete, Final cost, Variance, Consumed: seven
        // em dashes on the off-quote row's own line, its `Paid` cell the one cell that is not one
        // of them — plus the total row's own standing four (`Committed`, `Remaining`, `Variance`,
        // `Consumed`, see the earlier tests' own comment on that row): eleven in all.
        expect(find.text(ocptBudgetEmptyValue), findsNWidgets(11));

        await tester.tap(find.text(tr.budgetCostTrackingOffQuoteLabel));
        await tester.pumpAndSettle();

        expect(selectedPosteId, isNull);
      },
    );
  });

  testWidgets(
    "the header shows both the Estimate to complete and the Final cost columns",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Poste one",
        simpleLabel: null,
        estimateToCompleteCents: null,
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

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(
        find.text(tr.budgetCostTrackingColumnEstimateToComplete.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(tr.budgetCostTrackingColumnFinalCost.toUpperCase()), findsOneWidget);
    },
  );

  group("Estimate to complete and Final cost", () {
    /// A poste quoted at 100.00 € (one line: 1 × 100.00 €).
    OcptBudgetPoste poste({required int? estimateToCompleteCents}) => OcptBudgetPoste(
      id: "poste-1",
      code: "1",
      label: "Poste one",
      simpleLabel: null,
      estimateToCompleteCents: estimateToCompleteCents,
      sortKey: "a0",
      lines: [_line(id: "line-1", posteId: "poste-1", amountCents: 10000)],
    );

    testWidgets(
      "shows the derived figure in dimmed ink, and the Final cost then equals the quote",
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            OcptBudgetCostTracking(
              postes: [poste(estimateToCompleteCents: null)],
              selectedPosteId: null,
              isSimplified: false,
              taxBasis: OcptBudgetTaxBasis.includingTax,
              defaultVatRateBasisPoints: null,
              currencyCode: "EUR",
              paidByPosteId: {
                "poste-1": const OcptBudgetCoveredTotal(
                  amountCents: 2000,
                  coveredLineCount: 1,
                  lineCount: 1,
                ),
              },
              committedCentsOf: (_) => 1000,
              offQuoteTotal: const OcptBudgetCoveredTotal(
                amountCents: 0,
                coveredLineCount: 0,
                lineCount: 0,
              ),
              isReadOnly: false,
              onPosteSelected: (_) {},
              onPosteCreationRequested: () {},
              onPosteReorderRequested: (_, {required moveUp}) {},
              onPosteDeletionRequested: (_) {},
            ),
          ),
        );

        final theme = Theme.of(tester.element(find.byType(OcptBudgetCostTracking)));
        // Quote 100.00 €, Paid 20.00 €, Committed 10.00 €: Remaining and the derived Estimate to
        // complete both read 70.00 € (max(0, 100 - 20 - 10)) — at least one of every widget
        // showing that text is painted in the dimmed ink the VAT-rate cell already uses for an
        // inherited rate.
        final dimmedText = ocptBudgetAmountLabel(7000, "EUR");
        final matches = tester.widgetList<Text>(find.text(dimmedText));
        expect(
          matches.any((text) => text.style?.color == theme.colorScheme.onSurfaceVariant),
          isTrue,
          reason: "no widget reading $dimmedText is painted in the dimmed ink",
        );

        // Paid + Committed + the derived estimate brings the Final cost back to exactly the
        // quote: both the poste's own row and the total row draw 100.00 € for each of the two
        // columns, four widgets in all.
        expect(find.text(ocptBudgetAmountLabel(10000, "EUR")), findsNWidgets(4));
      },
    );

    testWidgets(
      "a typed figure wins over the derived one, and prints in ordinary ink",
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            OcptBudgetCostTracking(
              postes: [poste(estimateToCompleteCents: 9000)],
              selectedPosteId: null,
              isSimplified: false,
              taxBasis: OcptBudgetTaxBasis.includingTax,
              defaultVatRateBasisPoints: null,
              currencyCode: "EUR",
              paidByPosteId: {
                "poste-1": const OcptBudgetCoveredTotal(
                  amountCents: 2000,
                  coveredLineCount: 1,
                  lineCount: 1,
                ),
              },
              committedCentsOf: (_) => 1000,
              offQuoteTotal: const OcptBudgetCoveredTotal(
                amountCents: 0,
                coveredLineCount: 0,
                lineCount: 0,
              ),
              isReadOnly: false,
              onPosteSelected: (_) {},
              onPosteCreationRequested: () {},
              onPosteReorderRequested: (_, {required moveUp}) {},
              onPosteDeletionRequested: (_) {},
            ),
          ),
        );

        final theme = Theme.of(tester.element(find.byType(OcptBudgetCostTracking)));
        // The typed 90.00 € is drawn instead of the derived 70.00 € (Remaining, unaffected by the
        // typed estimate, still reads 70.00 € on its own) — no widget reading 90.00 € is painted
        // in the dimmed ink a derived figure would be.
        final typedText = ocptBudgetAmountLabel(9000, "EUR");
        final matches = tester.widgetList<Text>(find.text(typedText));
        expect(matches, isNotEmpty);
        expect(
          matches.every((text) => text.style?.color != theme.colorScheme.onSurfaceVariant),
          isTrue,
          reason: "a widget reading $typedText is painted in the dimmed ink",
        );

        // Final cost: 20.00 + 10.00 + 90.00 = 120.00 €.
        expect(find.text(ocptBudgetAmountLabel(12000, "EUR")), findsWidgets);
      },
    );
  });

  testWidgets(
    "the off-quote row prints the empty value for both Estimate to complete and Final cost",
    (tester) async {
      const offQuoteTotal = OcptBudgetCoveredTotal(amountCents: 2500, coveredLineCount: 1, lineCount: 1);

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

      // Seven em dashes on the off-quote row's own line, its `Paid` cell the one cell that is not
      // one of them — see the group above's own comment for the full count including the total
      // row's own standing four.
      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(11));
    },
  );

  testWidgets(
    "the total row sums the two new columns poste by poste, never re-derived from the grand "
    "Quote, Paid and Committed",
    (tester) async {
      final postes = [
        // Quote 100.00 €, Paid 30.00 €, Committed 20.00 €: derived Estimate to complete
        // 50.00 € (max(0, 100 - 30 - 20)), Final cost 100.00 € (30 + 20 + 50).
        OcptBudgetPoste(
          id: "poste-1",
          code: "1",
          label: "Poste one",
          simpleLabel: null,
          estimateToCompleteCents: null,
          sortKey: "a0",
          lines: [_line(id: "line-1", posteId: "poste-1", amountCents: 10000)],
        ),
        // Quote 60.00 €, Paid 10.00 €, Committed 5.00 €, a typed Estimate to complete of 40.00 €
        // (the derived one would have been 45.00 €): Final cost 55.00 € (10 + 5 + 40).
        OcptBudgetPoste(
          id: "poste-2",
          code: "2",
          label: "Poste two",
          simpleLabel: null,
          estimateToCompleteCents: 4000,
          sortKey: "a1",
          lines: [_line(id: "line-2", posteId: "poste-2", amountCents: 6000)],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: postes,
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidByPosteId: {
              "poste-1": const OcptBudgetCoveredTotal(
                amountCents: 3000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
              "poste-2": const OcptBudgetCoveredTotal(
                amountCents: 1000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            committedCentsOf: (posteId) => posteId == "poste-1" ? 2000 : 500,
            offQuoteTotal: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      // The honest grand Estimate to complete is 50.00 + 40.00 = 90.00 € — summed poste by poste,
      // the derived figure resolved for poste-1 and the typed one read verbatim for poste-2.
      // Re-deriving it from the grand Quote (160.00 €), Paid (40.00 €) and Committed (25.00 €)
      // would instead answer max(0, 160 - 40 - 25) = 95.00 €, which never appears anywhere.
      expect(find.text(ocptBudgetAmountLabel(9000, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(9500, "EUR")), findsNothing);

      // The grand Final cost is 100.00 + 55.00 = 155.00 €, once again summed poste by poste.
      expect(find.text(ocptBudgetAmountLabel(15500, "EUR")), findsOneWidget);
    },
  );
}
