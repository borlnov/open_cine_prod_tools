// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'ocpt_budget_fiche_test_doubles.dart';

void main() {
  testWidgets("shows the empty hint while nothing is selected", (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(testFiche()));

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets("shows the empty hint while the selection names a row that has since disappeared", (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(testFiche(selection: const OcptBudgetPosteSelection("gone"), postes: const [])),
    );

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  group("the poste variant", () {
    testWidgets(
      "shows the breadcrumb, the six figures, the remaining amount and the editable fields",
      (tester) async {
        await tester.pumpWidget(
          wrap(testFiche(selection: const OcptBudgetPosteSelection("poste-1"))),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetHeaderExpensesSegmentLabel), findsOneWidget);
        expect(find.text("Sets and costumes"), findsWidgets);
        // Quote is the line's own 10.00 €, nothing paid or committed against it yet.
        expect(find.text(ocptBudgetAmountLabel(1000, "EUR")), findsWidgets);
        expect(find.text(ocptBudgetAmountLabel(0, "EUR")), findsWidgets);
        // The figures row prints its own labels upper-cased, mirroring
        // `OcptBudgetCostTracking`'s own column headers.
        expect(find.text(tr.budgetInspectorFigureQuote.toUpperCase()), findsOneWidget);
        expect(find.text(tr.budgetInspectorFigureCommitted.toUpperCase()), findsWidgets);
        expect(find.text(tr.budgetInspectorFigurePaid.toUpperCase()), findsWidgets);
        expect(find.text(tr.budgetCostTrackingColumnFinalCost.toUpperCase()), findsOneWidget);
        expect(find.text(tr.budgetCostTrackingColumnVariance.toUpperCase()), findsOneWidget);
        // The outstanding block's own label is not upper-cased.
        expect(find.text(tr.budgetInspectorFigureRemaining), findsOneWidget);
        // No stepper draws for the poste variant any more — a poste is an aggregate, not a single
        // debt working through a lifecycle, and the stepper's own dots would lie about it.
        expect(find.byIcon(Icons.circle), findsNothing);
        expect(find.byIcon(Icons.circle_outlined), findsNothing);
        // The label field's own editable value, and the simple-label field's own hint — both
        // read "Sets and costumes", the label field's stored value and the simple label's own
        // fallback to it.
        expect(find.widgetWithText(TextField, "Sets and costumes"), findsWidgets);
      },
    );

    testWidgets("draws a proportion bar in place of the stepper", (tester) async {
      await tester.pumpWidget(
        wrap(testFiche(selection: const OcptBudgetPosteSelection("poste-1"))),
      );

      // The bar's own track: a Container of the proportion bar's own height, stretched to fill the
      // width the fiche gives it rather than a fixed one — on the 420-wide test surface it comes
      // out well past the 160 an earlier fixed pass drew, which is the whole point of the change.
      final track = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxHeight == 8 &&
            (widget.constraints?.maxWidth ?? 0) > 300,
      );
      expect(track, findsOneWidget);
    });

    testWidgets("draws neither a primary nor a secondary action, Add and From breakdown gone", (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(testFiche(selection: const OcptBudgetPosteSelection("poste-1"))),
      );

      // The poste's own Add/From breakdown actions moved to the capture wizard: no primary, no
      // secondary action is drawn on this variant any more.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets("a code shared with another live poste turns the code field red, keeping the "
        "typed value", (tester) async {
      const otherPoste = OcptBudgetPoste(
        id: "poste-2",
        code: "5",
        label: "Another poste",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a1",
        lines: [],
      );
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetPosteSelection("poste-1"),
            postes: const [testPoste, otherPoste],
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text(tr.budgetInspectorPosteCodeDuplicateError), findsOneWidget);
      // The typed value is kept, never reverted or blanked.
      expect(find.widgetWithText(TextField, "5"), findsOneWidget);
    });

    testWidgets("no error while no other live poste shares the same code", (tester) async {
      await tester.pumpWidget(
        wrap(testFiche(selection: const OcptBudgetPosteSelection("poste-1"))),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text(tr.budgetInspectorPosteCodeDuplicateError), findsNothing);
    });
  });

  group("the quote line variant", () {
    testWidgets("not promoted: Pay is primary, Commit and Delete the secondaries", (tester) async {
      useTallSurface(tester);
      String? paidLineId;
      String? committedLineId;
      String? deletedLineId;
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetLineSelection("line-1"),
            onLinePayDirectlyRequested: (lineId) => paidLineId = lineId,
            onLineCommitRequested: (lineId) => committedLineId = lineId,
            onLineDeletionRequested: (lineId) => deletedLineId = lineId,
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text("Crown"), findsWidgets);
      // Estimated reached only: one filled step, two hollow.
      expect(find.byIcon(Icons.circle), findsNWidgets(1));
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));

      // Pay is the primary gesture; it offers the line's own full quoted total.
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR")),
        ),
      );
      expect(paidLineId, "line-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetLineCommitAction));
      expect(committedLineId, "line-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetLineDeleteAction));
      expect(deletedLineId, "line-1");
    });

    testWidgets("promoted, unsettled: Pay is primary, Show/Cancel are the two secondaries", (
      tester,
    ) async {
      useTallSurface(tester);
      String? settledLineId;
      String? shownLineId;
      String? uncommittedLineId;
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetLineSelection("line-1"),
            commitments: [buildCommitment(lineId: "line-1")],
            onLineSettleRequested: (lineId) => settledLineId = lineId,
            onLineShowCommitmentRequested: (lineId) => shownLineId = lineId,
            onLineUncommitRequested: (lineId) => uncommittedLineId = lineId,
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.byIcon(Icons.circle), findsNWidgets(2));
      expect(
        find.widgetWithText(
          FilledButton,
          tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR")),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(
          FilledButton,
          tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR")),
        ),
      );
      expect(settledLineId, "line-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetLineShowCommitmentAction));
      expect(shownLineId, "line-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetLineUncommitAction));
      expect(uncommittedLineId, "line-1");

      expect(find.widgetWithText(OutlinedButton, tr.budgetLineDeleteAction), findsNothing);
      // Nothing has been paid at all: no payments section draws.
      expect(find.text(tr.budgetFicheCommitmentPaymentsSectionTitle.toUpperCase()), findsNothing);
    });

    testWidgets("promoted, part-paid: Pay offers the outstanding, not the full commitment, and the "
        "payments section lists the instalment", (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetLineSelection("line-1"),
            commitments: [buildCommitment(lineId: "line-1")],
            entries: [buildEntry(debitCents: 400, commitmentId: "commitment-1")],
            onLineSettleRequested: (_) {},
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      // Outstanding is 1000 - 400 = 600, not the commitment's own full 1000.
      final payLabel = tr.budgetFichePayAction(ocptBudgetAmountLabel(600, "EUR"));
      expect(find.widgetWithText(FilledButton, payLabel), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(600, "EUR")), findsWidgets);
      expect(
        find.widgetWithText(
          FilledButton,
          tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR")),
        ),
        findsNothing,
      );

      // The payments section lists the one instalment paid so far.
      expect(find.text(tr.budgetFicheCommitmentPaymentsSectionTitle.toUpperCase()), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(400, "EUR")), findsWidgets);
    });

    testWidgets("the payments section lists every instalment, oldest first", (tester) async {
      useTallSurface(tester);
      final laterEntry = OcptBudgetEntry(
        id: "entry-later",
        date: DateTime(2026, 8, 20),
        label: "Balance",
        posteId: "poste-1",
        debitCents: 200,
        creditCents: 0,
        isTaxInclusive: true,
        vatRateBasisPoints: null,
        voucherNumber: "J-002",
        sortKey: "a1",
        resourceId: null,
        revenueId: null,
        shareId: null,
        commitmentId: "commitment-1",
        personId: null,
      );
      final earlierEntry = OcptBudgetEntry(
        id: "entry-earlier",
        date: DateTime(2026, 8),
        label: "Deposit",
        posteId: "poste-1",
        debitCents: 800,
        creditCents: 0,
        isTaxInclusive: true,
        vatRateBasisPoints: null,
        voucherNumber: "J-001",
        sortKey: "a0",
        resourceId: null,
        revenueId: null,
        shareId: null,
        commitmentId: "commitment-1",
        personId: null,
      );

      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetLineSelection("line-1"),
            commitments: [buildCommitment(lineId: "line-1")],
            // Handed in latest first, on purpose — the section must still draw them oldest first.
            entries: [laterEntry, earlierEntry],
          ),
        ),
      );

      // The earlier, 8.00 € deposit sits above the later, 2.00 € balance — neither figure appears
      // anywhere else on this settled commitment's own fiche (its quote, committed and paid
      // figures all read 10.00 €), so each is found exactly once, in the payments section alone.
      expect(
        tester.getTopLeft(find.text(ocptBudgetAmountLabel(800, "EUR"))).dy,
        lessThan(tester.getTopLeft(find.text(ocptBudgetAmountLabel(200, "EUR"))).dy),
      );
    });

    testWidgets("promoted, settled: no primary, Delete is the only secondary", (tester) async {
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetLineSelection("line-1"),
            commitments: [buildCommitment(lineId: "line-1")],
            entries: [buildEntry(debitCents: 1000, commitmentId: "commitment-1")],
            onLineShowCommitmentRequested: (_) {},
            onLineDeletionRequested: (_) {},
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.byIcon(Icons.circle), findsNWidgets(3));
      expect(find.byType(FilledButton), findsNothing);
      // `Show the commitment` is offered from the unsettled branch alone — `À venir` holds
      // unsettled commitments only, so a settled one has nowhere left to be shown, even though
      // the callback itself is still handed in.
      expect(find.widgetWithText(OutlinedButton, tr.budgetLineShowCommitmentAction), findsNothing);
      expect(find.widgetWithText(OutlinedButton, tr.budgetLineDeleteAction), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, tr.budgetLineUncommitAction), findsNothing);
    });

    testWidgets(
      "a counterpart line is read-only, its only action opening the contribution it balances",
      (tester) async {
        const inKindLine = OcptBudgetLine(
          id: "line-1",
          posteId: "poste-1",
          label: "Camera loan",
          quantityMilli: 1000,
          unit: "u",
          unitPrice: OcptMoney(amountCents: 1000, isTaxInclusive: true, vatRateBasisPoints: 0),
          elementId: null,
          inKindResourceId: "resource-1",
          provisionKey: null,
          provisionDigest: null,
          notes: "",
          sortKey: "a0",
        );
        const inKindPoste = OcptBudgetPoste(
          id: "poste-1",
          code: "5",
          label: "Sets and costumes",
          simpleLabel: null,
          estimateToCompleteCents: null,
          sortKey: "a0",
          lines: [inKindLine],
        );

        OcptBudgetResource? edited;
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetLineSelection("line-1"),
              postes: const [inKindPoste],
              resources: [buildResource(groupKind: OcptBudgetResourceGroupKind.inKind)],
              onLinePayDirectlyRequested: (_) {},
              onLineCommitRequested: (_) {},
              onLineDeletionRequested: (_) {},
              onResourceEditRequested: (resource) => edited = resource,
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        // Pay/Commit/Delete are withheld; so are the editable fields and the
        // estimate/committed/paid stepper — a counterpart line is the contribution's to change.
        expect(find.widgetWithText(OutlinedButton, tr.budgetLineCommitAction), findsNothing);
        expect(find.widgetWithText(OutlinedButton, tr.budgetLineDeleteAction), findsNothing);
        expect(find.text(tr.budgetLineUnitPriceFieldLabel), findsNothing);
        expect(find.text(tr.budgetLineLabelFieldLabel), findsNothing);
        expect(find.text(tr.budgetInspectorFigurePaid), findsNothing);
        // It names the contribution it is covered by (`buildResource`'s own default label) and
        // shows the valuation read-only.
        expect(find.text(tr.budgetFicheInKindCounterpartHint("Region grant")), findsOneWidget);
        expect(find.text(tr.budgetResourceDialogValuedAtFieldLabel.toUpperCase()), findsOneWidget);

        // Its sole action opens that contribution for editing.
        await tester.tap(
          find.widgetWithText(FilledButton, tr.budgetFicheEditInKindContributionAction),
        );
        await tester.pumpAndSettle();
        expect(edited?.id, "resource-1");
      },
    );
  });

  group("the commitment variant", () {
    testWidgets("unsettled: Pay is primary, Edit and Delete are the two secondaries", (
      tester,
    ) async {
      useTallSurface(tester);
      OcptBudgetCommitment? settled;
      OcptBudgetCommitment? edited;
      String? deletedId;
      final commitment = buildCommitment(amountCents: 25000);

      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
            commitments: [commitment],
            onCommitmentSettleRequested: (c) => settled = c,
            onCommitmentEditRequested: (c) => edited = c,
            onCommitmentDeletionRequested: (id) => deletedId = id,
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text("Glass workshop"), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(25000, "EUR")), findsWidgets);
      expect(find.byIcon(Icons.circle), findsNWidgets(2));

      final payLabel = tr.budgetFichePayAction(ocptBudgetAmountLabel(25000, "EUR"));
      await tester.tap(find.widgetWithText(FilledButton, payLabel));
      expect(settled?.id, "commitment-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFinancingEditAction));
      expect(edited?.id, "commitment-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetCommittedDeleteAction));
      expect(deletedId, "commitment-1");
    });

    testWidgets("part-paid: Pay offers the outstanding, not the full commitment", (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
            commitments: [buildCommitment()],
            entries: [buildEntry(debitCents: 400, commitmentId: "commitment-1")],
            onCommitmentSettleRequested: (_) {},
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      // Outstanding is 1000 - 400 = 600, not the commitment's own full 1000 — the same reading the
      // promoted quote line's own fiche already offers.
      expect(
        find.widgetWithText(
          FilledButton,
          tr.budgetFichePayAction(ocptBudgetAmountLabel(600, "EUR")),
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          FilledButton,
          tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR")),
        ),
        findsNothing,
      );
    });

    testWidgets("settled: no primary, and the outstanding block reads the em dash", (tester) async {
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
            commitments: [buildCommitment()],
            entries: [buildEntry(debitCents: 1000, commitmentId: "commitment-1")],
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.circle), findsNWidgets(3));
      expect(find.text(ocptBudgetEmptyValue), findsWidgets);
    });

    testWidgets("the breadcrumb runs through the poste and the line it was promoted from", (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
            commitments: [buildCommitment(lineId: "line-1")],
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text("5 Sets and costumes"), findsOneWidget);
      expect(find.text("Crown"), findsOneWidget);
      expect(find.text(tr.budgetFicheKindCommitmentLabel), findsOneWidget);
    });
  });
}
