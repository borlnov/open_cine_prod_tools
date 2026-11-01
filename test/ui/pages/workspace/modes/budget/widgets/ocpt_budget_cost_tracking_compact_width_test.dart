// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';
import 'ocpt_budget_cost_tracking_test_doubles.dart';

/// Run the tests of the budget cost tracking compact width.
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
    int Function(String posteId) committedCentsOf = testZero,
    int Function(String posteId) inKindCoveredCentsOf = testZero,
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
    inKindCoveredCentsOf: inKindCoveredCentsOf,
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

  group("at a compact width", () {
    const posteOne = OcptBudgetPoste(
      id: "poste-1",
      code: "1",
      label: "Poste one",
      simpleLabel: null,
      estimateToCompleteCents: null,
      sortKey: "a0",
      lines: [],
    );
    const posteTwo = OcptBudgetPoste(
      id: "poste-2",
      code: "2",
      label: "Poste two",
      simpleLabel: null,
      estimateToCompleteCents: null,
      sortKey: "a1",
      lines: [],
    );

    testTestWidgets("draws one card per poste and no wide table", (tester) async {
      await tester.pumpWidget(
        wrap(buildTable(postes: [posteOne, posteTwo]), width: 500, height: 900),
      );

      expect(find.byType(Card), findsNWidgets(2));
      // The scrolling amounts pane only ever exists inside the wide, two-pane table.
      expect(find.byType(OcptHorizontalScrollView), findsNothing);
      expect(find.text("Poste one"), findsOneWidget);
      expect(find.text("Poste two"), findsOneWidget);
    });

    testTestWidgets("a card shows the poste's own Devis, Engagé, Payé, Reste and Écart figures", (
      tester,
    ) async {
      final poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Poste one",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a0",
        lines: [testLine(id: "line-1", posteId: "poste-1", amountCents: 10000)],
      );

      await tester.pumpWidget(
        wrap(
          buildTable(
            postes: [poste],
            paidByPosteId: {
              "poste-1": const OcptBudgetCoveredTotal(
                amountCents: 5000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            committedCentsOf: (id) => id == "poste-1" ? 1000 : 0,
          ),
          width: 500,
          height: 900,
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetCostTrackingColumnCommitted), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnPaid), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnRemaining), findsOneWidget);
      expect(find.text(tr.budgetCostTrackingColumnVariance), findsOneWidget);
      // Quote 100.00 €, Committed 10.00 €, Paid 50.00 €, Reste = 100 − 50 − 10 = 40.00 €,
      // Écart = 50 + 10 − 100 = −40.00 € — the very same `ocpt_budget_totals.dart` reads the
      // desktop row uses.
      expect(find.text(ocptBudgetAmountLabel(10000, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(1000, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(4000, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(-4000, "EUR")), findsOneWidget);
    });

    testTestWidgets("tapping a card selects its poste, exactly as tapping its row does", (
      tester,
    ) async {
      String? selectedPosteId;

      await tester.pumpWidget(
        wrap(
          buildTable(postes: [posteOne], onPosteSelected: (id) => selectedPosteId = id),
          width: 500,
          height: 900,
        ),
      );

      await tester.tap(find.text("Poste one"));

      expect(selectedPosteId, "poste-1");
    });

    testTestWidgets(
      "still selects under isReadOnly, since selecting a poste is a read rather than a write — "
      "exactly as OcptBudgetCostTracking.onPosteSelected is never gated on isReadOnly for the "
      "desktop row either",
      (tester) async {
        String? selectedPosteId;

        await tester.pumpWidget(
          wrap(
            buildTable(
              postes: [posteOne],
              isReadOnly: true,
              onPosteSelected: (id) => selectedPosteId = id,
            ),
            width: 500,
            height: 900,
          ),
        );

        await tester.tap(find.text("Poste one"));

        expect(selectedPosteId, "poste-1");
      },
    );

    testTestWidgets("highlights the currently selected poste's own card", (tester) async {
      await tester.pumpWidget(
        wrap(
          buildTable(
            postes: [posteOne, posteTwo],
            selection: const OcptBudgetPosteSelection("poste-1"),
          ),
          width: 500,
          height: 900,
        ),
      );

      final highlightedCount = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color != Colors.transparent)
          .length;

      expect(highlightedCount, 1);
    });

    testTestWidgets("keeps the desktop table unchanged above the breakpoint", (tester) async {
      await tester.pumpWidget(wrap(buildTable(postes: [posteOne, posteTwo])));

      expect(find.byType(Card), findsNothing);
      expect(find.byType(OcptHorizontalScrollView), findsOneWidget);
    });
  });
}
