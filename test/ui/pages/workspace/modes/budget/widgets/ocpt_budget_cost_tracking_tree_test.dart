// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'ocpt_budget_cost_tracking_test_doubles.dart';

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

  group("the tree", () {
    /// A poste with one quote line, priced at 20.00 €.
    OcptBudgetPoste posteWithLine() => OcptBudgetPoste(
      id: "poste-1",
      code: "1",
      label: "Poste one",
      simpleLabel: null,
      estimateToCompleteCents: null,
      sortKey: "a0",
      lines: [testLine(id: "line-1", posteId: "poste-1", amountCents: 2000, label: "Line one")],
    );

    testTestWidgets(
      "a poste with a line but no commitment and no off-line row still draws a twisty",
      (tester) async {
        await tester.pumpWidget(wrap(buildTable(postes: [posteWithLine()])));

        expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
        expect(find.text("Line one"), findsNothing);
      },
    );

    testTestWidgets("a poste row's own twisty is 28 wide over the row's full 48 px height", (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildTable(postes: [posteWithLine()])));

      final twistyInkWell = find
          .ancestor(of: find.byIcon(Icons.keyboard_arrow_right), matching: find.byType(InkWell))
          .first;
      final size = tester.getSize(twistyInkWell);

      expect(size.width, 28);
      expect(size.height, 48);
    });

    testTestWidgets("a row's own name sits level with its own figures, below an expanded poste", (
      tester,
    ) async {
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
            testLine(id: "line-1", posteId: "poste-1", amountCents: 2000, label: "Line one"),
            testLine(id: "line-2", posteId: "poste-1", amountCents: 500, label: "Line two"),
          ],
        ),
        OcptBudgetPoste(
          id: "poste-2",
          code: "2",
          label: "Poste two",
          simpleLabel: null,
          estimateToCompleteCents: null,
          sortKey: "a1",
          lines: [
            testLine(id: "line-3", posteId: "poste-2", amountCents: 7300, label: "Line three"),
          ],
        ),
      ];

      await tester.pumpWidget(
        wrap(buildTable(postes: postes, expandedNodeIds: const {"poste-1"}), height: 800),
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
    });

    testTestWidgets("a poste with nothing at all to expand onto draws no twisty", (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Empty poste",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a0",
        lines: [],
      );

      await tester.pumpWidget(wrap(buildTable(postes: [poste])));

      expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testTestWidgets("expanding a poste reveals its own line, and a line with no commitment draws "
        "no twisty of its own", (tester) async {
      await tester.pumpWidget(
        wrap(buildTable(postes: [posteWithLine()], expandedNodeIds: const {"poste-1"})),
      );

      expect(find.text("Line one"), findsOneWidget);
      // The poste's own twisty is now pointing down; the line beneath it has nothing to expand
      // onto, so there is exactly one twisty on screen.
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
    });

    testTestWidgets("a counterpart line shows the in-kind badge beside its own label; an ordinary "
        "line shows none", (tester) async {
      final poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Poste one",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a0",
        lines: [
          testLine(
            id: "line-1",
            posteId: "poste-1",
            label: "Line one",
            inKindResourceId: "resource-1",
          ),
          testLine(id: "line-2", posteId: "poste-1", label: "Line two"),
        ],
      );

      await tester.pumpWidget(
        wrap(buildTable(postes: [poste], expandedNodeIds: const {"poste-1"})),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetCostTrackingInKindLineBadge), findsOneWidget);
    });

    testTestWidgets(
      "a counterpart line's own Payé and Engagé cells read the em dash — a valuation is "
      "neither paid nor committed",
      (tester) async {
        final poste = OcptBudgetPoste(
          id: "poste-1",
          code: "1",
          label: "Poste one",
          simpleLabel: null,
          estimateToCompleteCents: null,
          sortKey: "a0",
          lines: [
            testLine(
              id: "line-1",
              posteId: "poste-1",
              amountCents: 5000,
              label: "Line one",
              inKindResourceId: "resource-1",
            ),
          ],
        );

        await tester.pumpWidget(
          wrap(buildTable(postes: [poste], expandedNodeIds: const {"poste-1"})),
        );

        // The total row's own Engagé, Reste and Écart cells always print the em dash (3 — see
        // "a poste with no entry or commitment against it..." above); the counterpart line's own
        // Payé and Engagé cells now do too, two more, five in all.
        expect(find.text(ocptBudgetEmptyValue), findsNWidgets(5));
      },
    );

    testTestWidgets("clicking a poste's own twisty toggles expansion without selecting it", (
      tester,
    ) async {
      String? toggledNodeId;
      String? selectedPosteId;

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("clicking a line row selects it, opening on the poste it belongs to", (
      tester,
    ) async {
      String? selectedLineId;

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("a line's own Devis, Engagé, Payé, Reste, Coût final and Écart read its own "
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
        testEntry(id: "entry-1", posteId: "poste-1", debitCents: 800, commitmentId: "commitment-2"),
      ];

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("a line with commitments expands to show them, an unsettled one printing its "
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
        testEntry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 800,
          label: "The payment",
          commitmentId: "commitment-2",
        ),
      ];

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("an unsettled commitment draws the muted 'no entry' hint instead of an entry "
        "row", (tester) async {
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1", amountCents: 500),
      ];

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("a commitment only part-paid draws its own instalment, not the no-entry hint", (
      tester,
    ) async {
      final commitments = [_commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1")];
      final entries = [
        testEntry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 400,
          label: "First instalment",
          commitmentId: "commitment-1",
        ),
      ];

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("the poste's own off-line commitments and entries draw at a line's own "
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
        testEntry(id: "entry-1", posteId: "poste-1", debitCents: 400, label: "Off-line entry"),
      ];

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("a paid off-line commitment is collapsed by default, hiding its payment", (
      tester,
    ) async {
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", amountCents: 890, label: "Green brief"),
      ];
      final entries = [
        testEntry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 890,
          label: "Green brief invoice",
          commitmentId: "commitment-1",
        ),
      ];

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("a paid off-line commitment reveals its payment once expanded", (tester) async {
      final commitments = [
        _commitment(id: "commitment-1", posteId: "poste-1", amountCents: 890, label: "Green brief"),
      ];
      final entries = [
        testEntry(
          id: "entry-1",
          posteId: "poste-1",
          debitCents: 890,
          label: "Green brief invoice",
          commitmentId: "commitment-1",
        ),
      ];

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("a commitment sub-row's own ⋮ menu offers Settle while unsettled, Undo "
        "settlement while settled, Edit and Delete", (tester) async {
      final unsettled = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("an entry sub-row's own ⋮ menu offers Edit and Delete", (tester) async {
      final commitment = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");
      final entry = testEntry(id: "entry-1", posteId: "poste-1", commitmentId: "commitment-1");

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("withholds every sub-row's own ⋮ menu while isReadOnly", (tester) async {
      final commitment = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");
      final entry = testEntry(id: "entry-1", posteId: "poste-1", commitmentId: "commitment-1");

      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("selecting a commitment or an entry highlights its own sub-row", (
      tester,
    ) async {
      final commitment = _commitment(id: "commitment-1", posteId: "poste-1", lineId: "line-1");
      final entry = testEntry(id: "entry-1", posteId: "poste-1", commitmentId: "commitment-1");

      await tester.pumpWidget(
        wrap(
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
    testTestWidgets("draws the empty hint and the feed card in place of the two-pane table", (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
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

    testTestWidgets("keeps the creation footer below the feed card, exactly as it is drawn today", (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildTable(onPosteCreationRequested: () {})));

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetPosteCreationAction), findsOneWidget);
    });

    testTestWidgets(
      "withholds the creation footer while isReadOnly, exactly as the populated table "
      "does",
      (tester) async {
        await tester.pumpWidget(
          wrap(buildTable(isReadOnly: true, onPosteCreationRequested: () {})),
        );

        final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
        expect(find.text(tr.budgetPosteCreationAction), findsNothing);
      },
    );

    testTestWidgets("every one of the feed card's own three rows reports its own click", (
      tester,
    ) async {
      var breakdownRequested = false;
      var scheduleRequested = false;
      var cateringRequested = false;

      await tester.pumpWidget(
        wrap(
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
