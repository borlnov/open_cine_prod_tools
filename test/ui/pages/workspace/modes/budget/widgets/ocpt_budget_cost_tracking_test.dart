// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
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
  String label = "",
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: label.isEmpty ? "Line $id" : label,
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

/// A commitment of [amountCents] (10.00 € by default), tax-inclusive, against [posteId], naming
/// [lineId] or none — settlement is read off whichever entries the test hands in alongside it,
/// through `ocptBudgetCommitmentIsSettledOf`, never a field of the commitment itself any more.
OcptBudgetCommitment _commitment({
  required String id,
  required String posteId,
  String? lineId,
  int amountCents = 1000,
  OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
  String label = "",
}) => OcptBudgetCommitment(
  id: id,
  dueDate: null,
  label: label.isEmpty ? "Commitment $id" : label,
  posteId: posteId,
  amount: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  status: status,
  lineId: lineId,
  sortKey: "a0",
);

/// A journal entry of [debitCents] (10.00 € by default), tax-inclusive, against [posteId], paying
/// [commitmentId] or none.
OcptBudgetEntry _entry({
  required String id,
  String? posteId,
  int debitCents = 1000,
  String label = "",
  String voucherNumber = "J-001",
  String? commitmentId,
}) => OcptBudgetEntry(
  id: id,
  date: DateTime(2026),
  label: label.isEmpty ? "Entry $id" : label,
  posteId: posteId,
  debitCents: debitCents,
  creditCents: 0,
  isTaxInclusive: true,
  vatRateBasisPoints: null,
  voucherNumber: voucherNumber,
  sortKey: "a0",
  resourceId: null,
  revenueId: null,
  shareId: null,
  commitmentId: commitmentId,
  personId: null,
);

void main() {
  /// Builds the table with every writing affordance withheld and every list empty, overridable
  /// field by field — every test below starts from this and only names what it actually varies.
  Widget buildTable({
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptBudgetEntry> entries = const [],
    OcptBudgetSelection? selection,
    Set<String> expandedNodeIds = const {},
    bool isSimplified = false,
    OcptBudgetTaxBasis taxBasis = OcptBudgetTaxBasis.includingTax,
    int? defaultVatRateBasisPoints,
    Map<String, OcptBudgetCoveredTotal> paidByPosteId = const {},
    int Function(String posteId) committedCentsOf = _zero,
    OcptBudgetCoveredTotal offQuoteTotal = const OcptBudgetCoveredTotal(
      amountCents: 0,
      coveredLineCount: 0,
      lineCount: 0,
    ),
    int breakdownPricedElementCount = 0,
    int breakdownUnpricedElementCount = 0,
    int shootingDayCount = 0,
    int mealCount = 0,
    int buffetCount = 0,
    bool isReadOnly = false,
    ValueChanged<String>? onPosteSelected,
    ValueChanged<String>? onLineSelected,
    ValueChanged<String>? onCommitmentSelected,
    ValueChanged<String>? onEntrySelected,
    ValueChanged<String>? onNodeExpansionToggled,
    VoidCallback? onPosteCreationRequested,
    void Function(String posteId, {required bool moveUp})? onPosteReorderRequested,
    ValueChanged<String>? onPosteDeletionRequested,
    ValueChanged<String>? onPosteFilterRequested,
    ValueChanged<OcptBudgetCommitment>? onCommitmentEditRequested,
    ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested,
    ValueChanged<String>? onCommitmentUnsettleRequested,
    ValueChanged<String>? onCommitmentDeletionRequested,
    ValueChanged<OcptBudgetEntry>? onEntryEditRequested,
    ValueChanged<String>? onEntryDeletionRequested,
    VoidCallback? onBreakdownFeedRequested,
    VoidCallback? onScheduleFeedRequested,
    VoidCallback? onCateringFeedRequested,
  }) => OcptBudgetCostTracking(
    postes: postes,
    commitments: commitments,
    entries: entries,
    selection: selection,
    expandedNodeIds: expandedNodeIds,
    isSimplified: isSimplified,
    taxBasis: taxBasis,
    defaultVatRateBasisPoints: defaultVatRateBasisPoints,
    currencyCode: "EUR",
    paidByPosteId: paidByPosteId,
    committedCentsOf: committedCentsOf,
    offQuoteTotal: offQuoteTotal,
    breakdownPricedElementCount: breakdownPricedElementCount,
    breakdownUnpricedElementCount: breakdownUnpricedElementCount,
    shootingDayCount: shootingDayCount,
    mealCount: mealCount,
    buffetCount: buffetCount,
    isReadOnly: isReadOnly,
    onPosteSelected: onPosteSelected ?? (_) {},
    onLineSelected: onLineSelected ?? (_) {},
    onCommitmentSelected: onCommitmentSelected ?? (_) {},
    onEntrySelected: onEntrySelected ?? (_) {},
    onNodeExpansionToggled: onNodeExpansionToggled ?? (_) {},
    onPosteCreationRequested: onPosteCreationRequested,
    onPosteReorderRequested: onPosteReorderRequested,
    onPosteDeletionRequested: onPosteDeletionRequested,
    onPosteFilterRequested: onPosteFilterRequested,
    onCommitmentEditRequested: onCommitmentEditRequested,
    onCommitmentSettleRequested: onCommitmentSettleRequested,
    onCommitmentUnsettleRequested: onCommitmentUnsettleRequested,
    onCommitmentDeletionRequested: onCommitmentDeletionRequested,
    onEntryEditRequested: onEntryEditRequested,
    onEntryDeletionRequested: onEntryDeletionRequested,
    onBreakdownFeedRequested: onBreakdownFeedRequested ?? () {},
    onScheduleFeedRequested: onScheduleFeedRequested ?? () {},
    onCateringFeedRequested: onCateringFeedRequested ?? () {},
  );

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
        lines: [_line(id: "line-1", posteId: "poste-1", vatRateBasisPoints: 2000)],
      );

      await tester.pumpWidget(_wrap(buildTable(postes: [poste])));

      expect(find.text("7"), findsOneWidget);
      expect(find.text("Technical equipment"), findsOneWidget);

      await tester.pumpWidget(_wrap(buildTable(postes: [poste], isSimplified: true)));

      expect(find.text("7"), findsNothing);
      expect(find.text("Camera and lighting gear"), findsOneWidget);
    },
  );

  testWidgets(
    "the header shows the six columns in the Devis, Engagé, Payé, Reste, Coût final, Écart order",
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

      await tester.pumpWidget(_wrap(buildTable(postes: [poste])));

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetCostTrackingColumnQuote.toUpperCase()), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnCommitted.toUpperCase()), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnPaid.toUpperCase()), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnRemaining.toUpperCase()), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnFinalCost.toUpperCase()), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnVariance.toUpperCase()), findsOneWidget);
      // The two columns this milestone drops leave the table altogether.
      expect(find.text(tr.budgetCostTrackingColumnEstimateToComplete.toUpperCase()), findsNothing);
      expect(find.text(tr.budgetCostTrackingColumnConsumed.toUpperCase()), findsNothing);
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
          lines: [_line(id: "line-1", posteId: "poste-1", vatRateBasisPoints: 2000)],
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
        _wrap(buildTable(postes: postes, taxBasis: OcptBudgetTaxBasis.excludingTax)),
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
    "withholds the creation footer and every poste row's own ⋮ menu while isReadOnly",
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
          buildTable(
            postes: [poste],
            isReadOnly: true,
            onPosteCreationRequested: () {},
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
      await tester.pumpWidget(_wrap(buildTable(postes: [poste]), width: 620));

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
        _wrap(buildTable(postes: postes, selection: const OcptBudgetPosteSelection("poste-1"))),
      );

      // One `ColoredBox` per pane per row (identity, amounts) — exactly two of the four painted
      // here (two postes, two panes) leave the selected poste's own transparent default.
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

      // Narrow enough that the `Poste` column sits at its own floor in both modes, so the pinned
      // pane's own width changes by exactly the `N°` column's width rather than the `Poste`
      // column silently absorbing the difference (which it does the moment there is room to
      // spare).
      await tester.pumpWidget(
        _wrap(buildTable(postes: [poste]), width: 620),
      );
      final detailedAmountsPaneLeftEdge = tester
          .getTopLeft(_amountsPaneScrollFinder)
          .dx;

      await tester.pumpWidget(
        _wrap(buildTable(postes: [poste], isSimplified: true), width: 620),
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

  /// A poste quoted at 50.00 € (one line: 1 × 50.00 €).
  OcptBudgetPoste quotedPoste({int? estimateToCompleteCents}) => OcptBudgetPoste(
    id: "poste-1",
    code: "1",
    label: "Poste one",
    simpleLabel: null,
    estimateToCompleteCents: estimateToCompleteCents,
    sortKey: "a0",
    lines: [
      const OcptBudgetLine(
        id: "line-1",
        posteId: "poste-1",
        label: "Line one",
        quantityMilli: 1000,
        unit: "u",
        unitPrice: OcptMoney(amountCents: 5000, isTaxInclusive: true, vatRateBasisPoints: null),
        elementId: null,
        provisionKey: null,
        provisionDigest: null,
        notes: "",
        sortKey: "a0",
      ),
    ],
  );

  testWidgets(
    "a poste whose entries have been paid shows the real figures for Payé, Engagé, Reste, "
    "Coût final and Écart",
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [quotedPoste()],
            paidByPosteId: {
              "poste-1": const OcptBudgetCoveredTotal(
                amountCents: 1200,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            committedCentsOf: (_) => 300,
          ),
        ),
      );

      // Quoted 50.00 €, Payé 12.00 €, Engagé 3.00 €, Reste 35.00 € (50 - 12 - 3), derived
      // estimate to complete max(0, 35) = 35.00 € (not drawn), Coût final 50.00 € (12 + 3 + 35),
      // Écart -35.00 € (12 + 3 - 50). The single poste's own Payé figure is also the whole
      // table's grand Payé total (no off-quote spending here), so 12.00 € is drawn twice: this
      // poste's own row, and the total row.
      expect(find.text(ocptBudgetAmountLabel(1200, "EUR")), findsNWidgets(2));
      expect(find.text(ocptBudgetAmountLabel(300, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(3500, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(-3500, "EUR")), findsOneWidget);
      // Coût final: 50.00 € drawn twice (this poste's own row, and the total row) — on top of
      // the 50.00 € quote itself drawn twice the very same way, four in all.
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsNWidgets(4));
      // The total row's own `Engagé`, `Reste` and `Écart` cells always print the em dash (there
      // is no grand reading for any of them); this poste's own row contributes none of its own.
      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(3));
    },
  );

  testWidgets(
    "a poste with no entry or commitment against it shows zero rather than a hole for Payé and "
    "Engagé",
    (tester) async {
      await tester.pumpWidget(_wrap(buildTable(postes: [quotedPoste()])));

      // Payé and Engagé both read a real zero on this poste's own row — nothing having moved
      // against it is a known fact now that the journal exists, not a stand-in for an unknown
      // figure — and the grand Payé total in the total row is the very same real zero, once
      // more: three widgets in all.
      expect(find.text(ocptBudgetAmountLabel(0, "EUR")), findsNWidgets(3));
      // Only the total row's own `Engagé`, `Reste` and `Écart` cells print the em dash here.
      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(3));
    },
  );

  testWidgets(
    "a poste row's own ⋮ menu offers Show this poste only, reporting the poste's own id",
    (tester) async {
      String? filteredPosteId;

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [quotedPoste()],
            onPosteFilterRequested: (posteId) => filteredPosteId = posteId,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      final menuFinder = find.byType(PopupMenuButton<String>);
      await tester.ensureVisible(menuFinder);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.budgetCostTrackingFilterOnlyAction));
      await tester.pumpAndSettle();

      expect(filteredPosteId, "poste-1");
    },
  );

  testWidgets(
    "withholds the poste row's Show this poste only entry under isReadOnly, unlike every other "
    "entry of that same menu — it only ever reads the project",
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [quotedPoste()],
            isReadOnly: true,
            onPosteFilterRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      final menuFinder = find.byType(PopupMenuButton<String>);
      await tester.ensureVisible(menuFinder);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetCostTrackingFilterOnlyAction), findsOneWidget);
      expect(find.text(tr.budgetPosteRenameAction), findsNothing);
      expect(find.text(tr.budgetPosteDeleteAction), findsNothing);
    },
  );

  group("the off-quote row", () {
    /// 25.00 € worth of debits naming no poste at all, fully covered.
    const offQuoteTotal = OcptBudgetCoveredTotal(amountCents: 2500, coveredLineCount: 1, lineCount: 1);

    testWidgets("is drawn between the last poste and the Total row while there is off-quote spending", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(buildTable(postes: [quotedPoste()], offQuoteTotal: offQuoteTotal)),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetCostTrackingOffQuoteLabel), findsOneWidget);
      // Its own Payé cell reads the off-quote total, and, since no poste itself was paid, the
      // total row's own grand Payé figure reads the very same amount — drawn twice.
      expect(find.text(ocptBudgetAmountLabel(2500, "EUR")), findsNWidgets(2));
    });

    testWidgets("is absent while there is no off-quote spending at all", (tester) async {
      await tester.pumpWidget(_wrap(buildTable(postes: [quotedPoste()])));

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
            buildTable(
              postes: [quotedPoste()],
              offQuoteTotal: offQuoteTotal,
              onPosteSelected: (posteId) => selectedPosteId = posteId,
            ),
          ),
        );

        final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
        // Exactly one ⋮ menu on screen: the single poste's own — none for the off-quote row.
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);

        // Devis, Engagé, Reste, Coût final, Écart: five em dashes on the off-quote row's own
        // line, its `Payé` cell the one cell that is not one of them — plus the total row's own
        // standing three (`Engagé`, `Reste`, `Écart`): eight in all.
        expect(find.text(ocptBudgetEmptyValue), findsNWidgets(8));

        await tester.tap(find.text(tr.budgetCostTrackingOffQuoteLabel));
        await tester.pumpAndSettle();

        expect(selectedPosteId, isNull);
      },
    );

    testWidgets("draws a twisty while it holds something to expand onto", (tester) async {
      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [quotedPoste()],
            entries: [_entry(id: "e1", debitCents: 2500)],
            offQuoteTotal: offQuoteTotal,
          ),
        ),
      );

      // The poste's own twisty (one line to expand onto) plus the off-quote row's own: two closed
      // arrows on screen.
      expect(find.byIcon(Icons.keyboard_arrow_right), findsNWidgets(2));
    });

    testWidgets(
      "toggling its own twisty reports its own reserved id, distinct from any poste or line",
      (tester) async {
        String? toggledId;

        await tester.pumpWidget(
          _wrap(
            buildTable(
              postes: [quotedPoste()],
              entries: [_entry(id: "e1", debitCents: 2500)],
              offQuoteTotal: offQuoteTotal,
              onNodeExpansionToggled: (id) => toggledId = id,
            ),
          ),
        );

        // The off-quote row draws after the poste in the tree, so its own twisty is the second —
        // and last — closed arrow on screen.
        await tester.tap(find.byIcon(Icons.keyboard_arrow_right).last);
        await tester.pumpAndSettle();

        expect(toggledId, isNotNull);
        expect(toggledId, isNot("poste-1"));
        expect(toggledId, isNot("line-1"));
      },
    );

    testWidgets(
      "once expanded, reveals the poste-less debits it sums, each selectable and carrying its "
      "own ⋮ menu",
      (tester) async {
        String? capturedToggleId;
        String? selectedEntryId;
        OcptBudgetEntry? editedEntry;
        final entries = [_entry(id: "e1", debitCents: 2500, label: "Off-quote spend")];

        // First pump: read back whichever id the twisty itself reports.
        await tester.pumpWidget(
          _wrap(
            buildTable(
              postes: [quotedPoste()],
              entries: entries,
              offQuoteTotal: offQuoteTotal,
              onNodeExpansionToggled: (id) => capturedToggleId = id,
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.keyboard_arrow_right).last);
        await tester.pumpAndSettle();
        final sentinelId = capturedToggleId!;

        // Second pump: that very id, now in expandedNodeIds, opens the row onto its own entry.
        await tester.pumpWidget(
          _wrap(
            buildTable(
              postes: [quotedPoste()],
              entries: entries,
              offQuoteTotal: offQuoteTotal,
              expandedNodeIds: {sentinelId},
              onEntrySelected: (entryId) => selectedEntryId = entryId,
              onEntryEditRequested: (entry) => editedEntry = entry,
            ),
          ),
        );

        expect(find.text("Off-quote spend"), findsOneWidget);

        await tester.tap(find.text("Off-quote spend"));
        await tester.pumpAndSettle();
        expect(selectedEntryId, "e1");

        // The poste's own ⋮ menu plus this entry sub-row's own: two menus on screen.
        final menus = find.byType(PopupMenuButton<String>);
        expect(menus, findsNWidgets(2));

        // The last one is this entry sub-row's own — the scrolling pane's own list draws the
        // poste's row first, this one after it — but it sits past the amounts pane's own
        // horizontal scroll, exactly as the tree's own established `⋮` menu tests already scroll
        // to it first.
        final entryMenu = menus.last;
        await tester.ensureVisible(entryMenu);
        await tester.tap(entryMenu);
        await tester.pumpAndSettle();
        final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
        await tester.tap(find.text(tr.budgetFinancingEditAction));
        await tester.pumpAndSettle();

        expect(editedEntry?.id, "e1");
      },
    );
  });

  group("Coût final", () {
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

    testWidgets("reads the quote itself while the derived estimate leaves nothing over", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [poste(estimateToCompleteCents: null)],
            paidByPosteId: {
              "poste-1": const OcptBudgetCoveredTotal(
                amountCents: 2000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            committedCentsOf: (_) => 1000,
          ),
        ),
      );

      // Quote 100.00 €, Payé 20.00 €, Engagé 10.00 €: Reste and the derived estimate to complete
      // both read 70.00 € (max(0, 100 - 20 - 10)), so Coût final (20 + 10 + 70) comes back to
      // exactly the quote — this poste's own row and the total row each draw 100.00 € for both
      // Devis and Coût final, four widgets in all.
      expect(find.text(ocptBudgetAmountLabel(10000, "EUR")), findsNWidgets(4));
    });

    testWidgets("a typed estimate to complete moves it past the quote", (tester) async {
      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [poste(estimateToCompleteCents: 9000)],
            paidByPosteId: {
              "poste-1": const OcptBudgetCoveredTotal(
                amountCents: 2000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            committedCentsOf: (_) => 1000,
          ),
        ),
      );

      // Coût final: 20.00 + 10.00 + 90.00 (typed) = 120.00 €, on both the poste's own row and the
      // total row.
      expect(find.text(ocptBudgetAmountLabel(12000, "EUR")), findsNWidgets(2));
    });
  });

  testWidgets(
    "the off-quote row prints the empty value for Coût final",
    (tester) async {
      const offQuoteTotal = OcptBudgetCoveredTotal(amountCents: 2500, coveredLineCount: 1, lineCount: 1);

      await tester.pumpWidget(
        _wrap(buildTable(postes: [quotedPoste()], offQuoteTotal: offQuoteTotal)),
      );

      // See the off-quote group's own comment for the full count.
      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(8));
    },
  );

  testWidgets(
    "the total row sums Coût final poste by poste, never re-derived from the grand Devis, Payé "
    "and Engagé",
    (tester) async {
      final postes = [
        // Quote 100.00 €, Payé 30.00 €, Engagé 20.00 €: derived estimate to complete 50.00 €
        // (max(0, 100 - 30 - 20)), Coût final 100.00 € (30 + 20 + 50).
        OcptBudgetPoste(
          id: "poste-1",
          code: "1",
          label: "Poste one",
          simpleLabel: null,
          estimateToCompleteCents: null,
          sortKey: "a0",
          lines: [_line(id: "line-1", posteId: "poste-1", amountCents: 10000)],
        ),
        // Quote 60.00 €, Payé 10.00 €, Engagé 5.00 €, a typed estimate to complete of 40.00 €
        // (the derived one would have been 45.00 €): Coût final 55.00 € (10 + 5 + 40).
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
          buildTable(
            postes: postes,
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
          ),
        ),
      );

      // The honest grand Coût final is 100.00 + 55.00 = 155.00 € — summed poste by poste, the
      // derived figure resolved for poste-1 and the typed one read verbatim for poste-2. A wrong
      // re-derivation from the grand Devis (160.00 €), Payé (40.00 €) and Engagé (25.00 €) —
      // 40 + 25 + max(0, 160 - 40 - 25) — would instead collapse to the grand Devis itself, which
      // is on screen anyway (the total row's own `Devis` cell), so 155.00 € is the one figure
      // that tells the two readings apart.
      expect(find.text(ocptBudgetAmountLabel(15500, "EUR")), findsOneWidget);
    },
  );

  group("the tree", () {
    /// A poste with one quote line, priced at 20.00 €.
    OcptBudgetPoste posteWithLine() => OcptBudgetPoste(
      id: "poste-1",
      code: "1",
      label: "Poste one",
      simpleLabel: null,
      estimateToCompleteCents: null,
      sortKey: "a0",
      lines: [_line(id: "line-1", posteId: "poste-1", amountCents: 2000, label: "Line one")],
    );

    testWidgets("a poste with a line but no commitment and no off-line row still draws a twisty", (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(buildTable(postes: [posteWithLine()])));

      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
      expect(find.text("Line one"), findsNothing);
    });

    testWidgets("a poste row's own twisty is 28 wide over the row's full 48 px height", (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(buildTable(postes: [posteWithLine()])));

      final twistyInkWell = find
          .ancestor(of: find.byIcon(Icons.keyboard_arrow_right), matching: find.byType(InkWell))
          .first;
      final size = tester.getSize(twistyInkWell);

      expect(size.width, 28);
      expect(size.height, 48);
    });

    testWidgets(
      "a row's own name sits level with its own figures, below an expanded poste",
      (tester) async {
        // The two panes are laid out independently and share only a vertical scroll, so a row
        // whose halves disagree on their height silently slides every row under it out of step:
        // a poste ends up named beside the poste above's money. Each amount below is unique to
        // one row, so the match cannot be an accident of two rows reading alike.
        final postes = [
          OcptBudgetPoste(
            id: "poste-1",
            code: "1",
            label: "Poste one",
            simpleLabel: null,
            estimateToCompleteCents: null,
            sortKey: "a0",
            lines: [
              _line(id: "line-1", posteId: "poste-1", amountCents: 2000, label: "Line one"),
              _line(id: "line-2", posteId: "poste-1", amountCents: 500, label: "Line two"),
            ],
          ),
          OcptBudgetPoste(
            id: "poste-2",
            code: "2",
            label: "Poste two",
            simpleLabel: null,
            estimateToCompleteCents: null,
            sortKey: "a1",
            lines: [_line(id: "line-3", posteId: "poste-2", amountCents: 7300, label: "Line three")],
          ),
        ];

        await tester.pumpWidget(
          _wrap(
            buildTable(postes: postes, expandedNodeIds: const {"poste-1"}),
            height: 800,
          ),
        );

        // The expanded poste's own first line: its name on the left, its quote on the right.
        expect(
          tester.getCenter(find.text("Line one")).dy,
          tester.getCenter(find.text("€20.00").first).dy,
        );

        // And the poste below the expansion, which is where any drift has accumulated.
        expect(
          tester.getCenter(find.text("Poste two")).dy,
          tester.getCenter(find.text("€73.00").first).dy,
        );
      },
    );

    testWidgets("a poste with nothing at all to expand onto draws no twisty", (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Empty poste",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a0",
        lines: [],
      );

      await tester.pumpWidget(_wrap(buildTable(postes: [poste])));

      expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets("expanding a poste reveals its own line, and a line with no commitment draws "
        "no twisty of its own", (tester) async {
      await tester.pumpWidget(
        _wrap(buildTable(postes: [posteWithLine()], expandedNodeIds: const {"poste-1"})),
      );

      expect(find.text("Line one"), findsOneWidget);
      // The poste's own twisty is now pointing down; the line beneath it has nothing to expand
      // onto, so there is exactly one twisty on screen.
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
    });

    testWidgets("clicking a poste's own twisty toggles expansion without selecting it", (
      tester,
    ) async {
      String? toggledNodeId;
      String? selectedPosteId;

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            onNodeExpansionToggled: (nodeId) => toggledNodeId = nodeId,
            onPosteSelected: (posteId) => selectedPosteId = posteId,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.keyboard_arrow_right));
      await tester.pumpAndSettle();

      expect(toggledNodeId, "poste-1");
      expect(selectedPosteId, isNull);
    });

    testWidgets("clicking a line row selects it, opening on the poste it belongs to", (
      tester,
    ) async {
      String? selectedLineId;

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            expandedNodeIds: const {"poste-1"},
            onLineSelected: (lineId) => selectedLineId = lineId,
          ),
        ),
      );

      await tester.tap(find.text("Line one"));
      await tester.pumpAndSettle();

      expect(selectedLineId, "line-1");
    });

    testWidgets("a line's own Devis, Engagé, Payé, Reste, Coût final and Écart read its own "
        "commitments and their settling entries, never the poste's", (tester) async {
      final poste = posteWithLine();
      // Line one is quoted at 20.00 €: one unsettled commitment of 5.00 € (Engagé), one settled
      // commitment of 8.00 €, paid in full by an 8.00 € entry naming it (Payé reads what has
      // actually been paid against it, not the commitment's own amount, though the two agree once
      // it is settled) — Reste 20 - 5 - 8 = 7.00 €, derived estimate to complete max(0, 7) =
      // 7.00 €, Coût final 5 + 8 + 7 = 20.00 €, Écart 5 + 8 - 20 = -7.00 €.
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1", amountCents: 500),
        _commitment(id: "commitment-2", posteId: "poste-1", lineId: "line-1", amountCents: 800),
      ];
      final entries = [
        _entry(id: "entry-1", posteId: "poste-1", debitCents: 800, commitmentId: "commitment-2"),
      ];

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [poste],
            commitments: commitments,
            entries: entries,
            expandedNodeIds: const {"poste-1"},
          ),
        ),
      );

      // Devis (2000) is left unchecked here: the poste's own row reads the very same 20.00 €,
      // since it holds this one line alone, so the figure would not tell the two rows apart.
      expect(find.text(ocptBudgetAmountLabel(500, "EUR")), findsOneWidget); // Engagé
      expect(find.text(ocptBudgetAmountLabel(800, "EUR")), findsOneWidget); // Payé
      expect(find.text(ocptBudgetAmountLabel(-700, "EUR")), findsOneWidget); // Écart
    });

    testWidgets("a line with commitments expands to show them, an unsettled one printing its "
        "own amount in Engagé and a settled one in Payé", (tester) async {
      final commitments = [
        _commitment(
          id: "commitment-1",
          posteId: "poste-1",
          lineId: "line-1",
          amountCents: 500,
          label: "The rental quote",
        ),
        _commitment(
          id: "commitment-2",
          posteId: "poste-1",
          lineId: "line-1",
          amountCents: 800,
          label: "The invoice",
        ),
      ];
      final entries = [
        _entry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 800,
          label: "The payment",
          commitmentId: "commitment-2",
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: commitments,
            entries: entries,
            expandedNodeIds: const {"poste-1", "line-1"},
          ),
        ),
      );

      expect(find.text("The rental quote"), findsOneWidget);
      expect(find.text("The invoice"), findsOneWidget);
      expect(find.text("The payment"), findsOneWidget);
      // The unsettled commitment's own 5.00 € (in its own Engagé) is also the line's own Engagé,
      // its own single unsettled commitment: two widgets. The settled one's own 8.00 € (in its
      // own Payé, its own amount) agrees with both the entry's own 8.00 € debit and the line's
      // own Payé (the very same entry, being its only settled commitment): three widgets.
      expect(find.text(ocptBudgetAmountLabel(500, "EUR")), findsNWidgets(2));
      expect(find.text(ocptBudgetAmountLabel(800, "EUR")), findsNWidgets(3));
    });

    testWidgets("an unsettled commitment draws the muted 'no entry' hint instead of an entry "
        "row", (tester) async {
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1", amountCents: 500),
      ];

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: commitments,
            expandedNodeIds: const {"poste-1", "line-1"},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetCostTrackingNoEntryHint), findsOneWidget);
    });

    testWidgets("a commitment only part-paid draws its own instalment, not the no-entry hint", (
      tester,
    ) async {
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1"),
      ];
      final entries = [
        _entry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 400,
          label: "First instalment",
          commitmentId: "commitment-1",
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: commitments,
            entries: entries,
            expandedNodeIds: const {"poste-1", "line-1"},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text("First instalment"), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingNoEntryHint), findsNothing);
    });

    testWidgets("the poste's own off-line commitments and entries draw at a line's own "
        "indentation once the poste is expanded", (tester) async {
      final commitments = [
        // No lineId: an off-line commitment.
        _commitment(
          id: "commitment-1",
          posteId: "poste-1",
          amountCents: 300,
          label: "Off-line commitment",
        ),
      ];
      final entries = [
        _entry(id: "entry-1", posteId: "poste-1", debitCents: 400, label: "Off-line entry"),
      ];

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: commitments,
            entries: entries,
            expandedNodeIds: const {"poste-1"},
          ),
        ),
      );

      expect(find.text("Off-line commitment"), findsOneWidget);
      expect(find.text("Off-line entry"), findsOneWidget);
    });

    testWidgets("a paid off-line commitment is collapsed by default, hiding its payment", (
      tester,
    ) async {
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", amountCents: 890, label: "Green brief"),
      ];
      final entries = [
        _entry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 890,
          label: "Green brief invoice",
          commitmentId: "commitment-1",
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: commitments,
            entries: entries,
            expandedNodeIds: const {"poste-1"},
          ),
        ),
      );

      // The off-line commitment reads as one row — its payment folds away behind its own collapsed
      // twisty rather than drawing as a second, same-level, same-named row beside it.
      expect(find.text("Green brief"), findsOneWidget);
      expect(find.text("Green brief invoice"), findsNothing);
      // The poste is expanded (a down chevron), so the one right-facing chevron left is the
      // commitment's own — proving a paid off-line commitment is itself an expandable node.
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    });

    testWidgets("a paid off-line commitment reveals its payment once expanded", (tester) async {
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", amountCents: 890, label: "Green brief"),
      ];
      final entries = [
        _entry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 890,
          label: "Green brief invoice",
          commitmentId: "commitment-1",
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: commitments,
            entries: entries,
            expandedNodeIds: const {"poste-1", "commitment-1"},
          ),
        ),
      );

      expect(find.text("Green brief"), findsOneWidget);
      expect(find.text("Green brief invoice"), findsOneWidget);
    });

    testWidgets("a commitment sub-row's own ⋮ menu offers Settle while unsettled, Undo "
        "settlement while settled, Edit and Delete", (tester) async {
      final unsettled = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: [unsettled],
            expandedNodeIds: const {"poste-1", "line-1"},
            onCommitmentEditRequested: (_) {},
            onCommitmentSettleRequested: (_) {},
            onCommitmentUnsettleRequested: (_) {},
            onCommitmentDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      // Index 1: the poste's own row draws its own ⋮ menu first (index 0), the commitment
      // sub-row's own menu comes next.
      final menuFinder = find.byType(PopupMenuButton<String>).at(1);
      await tester.ensureVisible(menuFinder);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetFinancingEditAction), findsOneWidget);
      expect(find.text(tr.budgetCommittedSettleAction), findsOneWidget);
      expect(find.text(tr.budgetCommittedUnsettleAction), findsNothing);
      expect(find.text(tr.budgetCommittedDeleteAction), findsOneWidget);
    });

    testWidgets("an entry sub-row's own ⋮ menu offers Edit and Delete", (tester) async {
      final commitment = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");
      final entry = _entry(id: "entry-1", posteId: "poste-1", commitmentId: "commitment-1");

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: [commitment],
            entries: [entry],
            expandedNodeIds: const {"poste-1", "line-1"},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      // Index 1: the poste's own row draws its own ⋮ menu first (index 0); the settled
      // commitment's own menu is null here (every one of its own entries is withheld), so the
      // entry sub-row's own menu is the very next one.
      final menuFinder = find.byType(PopupMenuButton<String>).at(1);
      await tester.ensureVisible(menuFinder);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetFinancingEditAction), findsOneWidget);
      expect(find.text(tr.budgetEntryDeleteAction), findsOneWidget);
    });

    testWidgets("withholds every sub-row's own ⋮ menu while isReadOnly", (tester) async {
      final commitment = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");
      final entry = _entry(id: "entry-1", posteId: "poste-1", commitmentId: "commitment-1");

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: [commitment],
            entries: [entry],
            expandedNodeIds: const {"poste-1", "line-1"},
            isReadOnly: true,
            onCommitmentEditRequested: (_) {},
            onCommitmentDeletionRequested: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets("selecting a commitment or an entry highlights its own sub-row", (tester) async {
      final commitment = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");
      final entry = _entry(id: "entry-1", posteId: "poste-1", commitmentId: "commitment-1");

      await tester.pumpWidget(
        _wrap(
          buildTable(
            postes: [posteWithLine()],
            commitments: [commitment],
            entries: [entry],
            expandedNodeIds: const {"poste-1", "line-1"},
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
          ),
        ),
      );

      final highlightedCount = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color != Colors.transparent)
          .length;
      // The commitment's own sub-row is drawn in two panes, both highlighted.
      expect(highlightedCount, 2);
    });
  });

  group("the empty state", () {
    testWidgets("draws the empty hint and the feed card in place of the two-pane table", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          buildTable(
            breakdownPricedElementCount: 3,
            breakdownUnpricedElementCount: 2,
            shootingDayCount: 12,
            mealCount: 8,
            buffetCount: 8,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetDashboardEmptyHint), findsOneWidget);
      expect(find.byType(OcptBudgetFeedCard), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedBreakdownReadOut(3, 5)), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedScheduleReadOut(12)), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedCateringReadOut(8, 8)), findsOneWidget);
    });

    testWidgets("keeps the creation footer below the feed card, exactly as it is drawn today", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(buildTable(onPosteCreationRequested: () {})),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetPosteCreationAction), findsOneWidget);
    });

    testWidgets("withholds the creation footer while isReadOnly, exactly as the populated table "
        "does", (tester) async {
      await tester.pumpWidget(
        _wrap(
          buildTable(isReadOnly: true, onPosteCreationRequested: () {}),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetPosteCreationAction), findsNothing);
    });

    testWidgets("every one of the feed card's own three rows reports its own click", (tester) async {
      var breakdownRequested = false;
      var scheduleRequested = false;
      var cateringRequested = false;

      await tester.pumpWidget(
        _wrap(
          buildTable(
            onBreakdownFeedRequested: () => breakdownRequested = true,
            onScheduleFeedRequested: () => scheduleRequested = true,
            onCateringFeedRequested: () => cateringRequested = true,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      await tester.tap(find.text(tr.budgetDashboardFeedBreakdownTitle));
      await tester.tap(find.text(tr.budgetDashboardFeedScheduleTitle));
      await tester.tap(find.text(tr.budgetDashboardFeedCateringTitle));
      await tester.pumpAndSettle();

      expect(breakdownRequested, isTrue);
      expect(scheduleRequested, isTrue);
      expect(cateringRequested, isTrue);
    });
  });
}

/// A `committedCentsOf` reading everything as zero — the default of `buildTable`'s own optional
/// parameter.
int _zero(String posteId) => 0;
