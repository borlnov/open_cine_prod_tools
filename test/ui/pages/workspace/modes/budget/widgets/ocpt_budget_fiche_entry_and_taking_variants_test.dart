// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'ocpt_budget_fiche_test_doubles.dart';

/// Builds a taking, everything but what a test actually varies neutral.
OcptBudgetRevenue _buildRevenue({
  String id = "revenue-1",
  int amountCents = 50000,
  OcptBudgetRevenueStatus status = OcptBudgetRevenueStatus.confirmed,
}) => OcptBudgetRevenue(
  id: id,
  date: DateTime(2026, 6),
  label: "Festival prize",
  amountCents: amountCents,
  status: status,
  notes: "",
  sortKey: "a0",
);

/// Run the tests of the budget fiche entry and taking variants.
void main() {
  group("the entry variant", () {
    testWidgets("Edit is primary, Delete the only secondary, and it carries no outstanding", (
      tester,
    ) async {
      useTallSurface(tester);
      OcptBudgetEntry? edited;
      String? deletedId;
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetEntrySelection("entry-1"),
            entries: [buildEntry(debitCents: 5000)],
            onEntryEditRequested: (entry) => edited = entry,
            onEntryDeletionRequested: (id) => deletedId = id,
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      expect(find.text(tr.budgetInspectorFigureRemaining), findsNothing);
      expect(find.text(tr.budgetCommittedOutstandingLabel), findsNothing);
      expect(find.text(tr.budgetFinancingColumnOutstanding), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, tr.budgetFinancingEditAction));
      expect(edited?.id, "entry-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetEntryDeleteAction));
      expect(deletedId, "entry-1");
    });

    testWidgets("withholds Edit and Delete under a previewed version", (tester) async {
      var written = false;
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetEntrySelection("entry-1"),
            entries: [buildEntry(debitCents: 5000)],
            isReadOnly: true,
            onEntryEditRequested: (_) => written = true,
            onEntryDeletionRequested: (_) => written = true,
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(written, isFalse);
    });

    group("the off-line-debit banner", () {
      testWidgets(
        "shows on a debit naming a poste but no commitment, and dispatches both its actions",
        (tester) async {
          useTallSurface(tester);
          var promoted = false;
          var movedOffQuote = false;
          await tester.pumpWidget(
            wrap(
              testFiche(
                selection: const OcptBudgetEntrySelection("entry-1"),
                // 500 against the poste's own 1,000 quote — not over, so no overrun clause.
                entries: [buildEntry(debitCents: 500)],
                onEntryPromoteToQuoteRequested: () => promoted = true,
                onEntryMoveOffQuoteRequested: () => movedOffQuote = true,
              ),
            ),
          );
          final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

          expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsOneWidget);

          await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction));
          expect(promoted, isTrue);

          await tester.tap(
            find.widgetWithText(OutlinedButton, tr.budgetFicheEntryMoveOffQuoteAction),
          );
          expect(movedOffQuote, isTrue);
        },
      );

      testWidgets("states the poste's own overrun once it is over its quote", (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              // 5,000 against the poste's own 1,000 quote — 4,000 over.
              entries: [buildEntry(debitCents: 5000)],
              onEntryPromoteToQuoteRequested: () {},
              onEntryMoveOffQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(
          find.text(
            tr.budgetFicheEntryOffLineBannerOverQuoteText(ocptBudgetAmountLabel(4000, "EUR")),
          ),
          findsOneWidget,
        );
        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsNothing);
      });

      testWidgets("withholds both actions under a previewed version, the text stays", (
        tester,
      ) async {
        useTallSurface(tester);
        var written = false;
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [buildEntry(debitCents: 500)],
              isReadOnly: true,
              onEntryPromoteToQuoteRequested: () => written = true,
              onEntryMoveOffQuoteRequested: () => written = true,
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction),
          findsNothing,
        );
        expect(
          find.widgetWithText(OutlinedButton, tr.budgetFicheEntryMoveOffQuoteAction),
          findsNothing,
        );
        expect(written, isFalse);
      });

      testWidgets("does not show once the entry already names a commitment", (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [buildEntry(debitCents: 500, commitmentId: "commitment-1")],
              commitments: [buildCommitment()],
              onEntryPromoteToQuoteRequested: () {},
              onEntryMoveOffQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsNothing);
      });

      testWidgets("does not show on a credit", (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [buildEntry(creditCents: 500)],
              onEntryPromoteToQuoteRequested: () {},
              onEntryMoveOffQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsNothing);
      });

      testWidgets("does not show on a debit naming no poste at all", (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [buildEntry(posteId: null, debitCents: 500)],
              onEntryPromoteToQuoteRequested: () {},
              onEntryMoveOffQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsNothing);
      });
    });

    group("the off-line-commitment banner", () {
      testWidgets("shows on a commitment naming no line, and dispatches its promote action", (
        tester,
      ) async {
        useTallSurface(tester);
        var promoted = false;
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              // 1,000, matching the poste's own 1,000 quote — not over, so no overrun clause.
              commitments: [buildCommitment()],
              onCommitmentPromoteToQuoteRequested: () => promoted = true,
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheCommitmentOffLineBannerText), findsOneWidget);
        // The one thing a commitment cannot do: it always names a poste, so no Move off-quote.
        expect(
          find.widgetWithText(OutlinedButton, tr.budgetFicheEntryMoveOffQuoteAction),
          findsNothing,
        );

        await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction));
        expect(promoted, isTrue);
      });

      testWidgets("states the poste's own overrun once it is over its quote", (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              // 5,000 committed against the poste's own 1,000 quote — 4,000 over.
              commitments: [buildCommitment(amountCents: 5000)],
              onCommitmentPromoteToQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(
          find.text(
            tr.budgetFicheCommitmentOffLineBannerOverQuoteText(ocptBudgetAmountLabel(4000, "EUR")),
          ),
          findsOneWidget,
        );
        expect(find.text(tr.budgetFicheCommitmentOffLineBannerText), findsNothing);
      });

      testWidgets("withholds its action under a previewed version, the text stays", (tester) async {
        useTallSurface(tester);
        var written = false;
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              commitments: [buildCommitment()],
              isReadOnly: true,
              onCommitmentPromoteToQuoteRequested: () => written = true,
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheCommitmentOffLineBannerText), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction),
          findsNothing,
        );
        expect(written, isFalse);
      });

      testWidgets("does not show once the commitment already names a line", (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              commitments: [buildCommitment(lineId: "line-1")],
              onCommitmentPromoteToQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheCommitmentOffLineBannerText), findsNothing);
      });
    });
  });

  group("the resource variant", () {
    testWidgets("cash, not fully received: Receive is primary, Edit/Delete the secondaries", (
      tester,
    ) async {
      useTallSurface(tester);
      OcptBudgetResource? received;
      OcptBudgetResource? edited;
      String? deletedId;
      final resource = buildResource();

      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetResourceSelection("resource-1"),
            resources: [resource],
            receivedByResourceId: {
              "resource-1": const OcptBudgetCoveredTotal(
                amountCents: 80000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            onResourceReceiptRequested: (r) => received = r,
            onResourceEditRequested: (r) => edited = r,
            onResourceDeletionRequested: (id) => deletedId = id,
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text("Region grant"), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(200000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(80000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(120000, "EUR")), findsWidgets);
      expect(
        find.text(ocptBudgetResourceStatusLabel(tr, resource.groupKind, resource.status)),
        findsOneWidget,
      );

      final receiveLabel = tr.budgetFicheReceiveAction(ocptBudgetAmountLabel(120000, "EUR"));
      await tester.tap(find.widgetWithText(FilledButton, receiveLabel));
      expect(received?.id, "resource-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFinancingEditAction));
      expect(edited?.id, "resource-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetCommittedDeleteAction));
      expect(deletedId, "resource-1");
    });

    testWidgets(
      "an uncollected in-kind resource drops the Promised/Received stepper for a Valued-at "
      "reading, and offers no Receive action",
      (tester) async {
        await tester.pumpWidget(
          wrap(
            testFiche(
              selection: const OcptBudgetResourceSelection("resource-1"),
              resources: [buildResource(groupKind: OcptBudgetResourceGroupKind.inKind)],
              onResourceReceiptRequested: (_) {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        // No Receive action, and no money-collection lifecycle: the Received figure is gone,
        // replaced by the valuation the contribution is worth. (Figure labels render uppercased.)
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text(tr.budgetFinancingColumnReceived.toUpperCase()), findsNothing);
        expect(find.text(tr.budgetResourceDialogValuedAtFieldLabel.toUpperCase()), findsOneWidget);
      },
    );

    testWidgets("an in-kind resource with a counterpart line names the poste it offsets", (
      tester,
    ) async {
      const offsetLine = OcptBudgetLine(
        id: "line-offset",
        posteId: "poste-2",
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
      const offsetPoste = OcptBudgetPoste(
        id: "poste-2",
        code: "7",
        label: "Technical equipment",
        simpleLabel: null,
        estimateToCompleteCents: null,
        sortKey: "a1",
        lines: [offsetLine],
      );

      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetResourceSelection("resource-1"),
            postes: const [testPoste, offsetPoste],
            resources: [buildResource(groupKind: OcptBudgetResourceGroupKind.inKind)],
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text(tr.budgetFicheInKindOffsetsPoste("7 Technical equipment")), findsOneWidget);
    });

    testWidgets("an in-kind resource with no counterpart line yet names no poste", (tester) async {
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetResourceSelection("resource-1"),
            resources: [buildResource(groupKind: OcptBudgetResourceGroupKind.inKind)],
          ),
        ),
      );

      // No card at all: an uncollected in-kind resource draws its "Valued at" figure bare (no
      // Promised/Received stepper card), and there is no poste-offset banner card since nothing
      // in `postes` names this resource's own id yet.
      expect(find.byType(Card), findsNothing);
    });

    testWidgets("withholds Receive once the resource is fully received", (tester) async {
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetResourceSelection("resource-1"),
            resources: [buildResource(amountCents: 50000)],
            receivedByResourceId: {
              "resource-1": const OcptBudgetCoveredTotal(
                amountCents: 50000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            onResourceReceiptRequested: (_) {},
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group("the taking variant", () {
    testWidgets("not fully received: Receive is primary, Edit/Delete the secondaries", (
      tester,
    ) async {
      useTallSurface(tester);
      OcptBudgetRevenue? received;
      OcptBudgetRevenue? edited;
      String? deletedId;
      final revenue = _buildRevenue();

      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetRevenueSelection("revenue-1"),
            revenues: [revenue],
            receivedByRevenueId: {
              "revenue-1": const OcptBudgetCoveredTotal(
                amountCents: 20000,
                coveredLineCount: 1,
                lineCount: 1,
              ),
            },
            onRevenueReceiptRequested: (r) => received = r,
            onRevenueEditRequested: (r) => edited = r,
            onRevenueDeletionRequested: (id) => deletedId = id,
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text("Festival prize"), findsWidgets);
      expect(find.text(ocptBudgetRevenueStatusLabel(tr, revenue.status)), findsOneWidget);

      final receiveLabel = tr.budgetFicheReceiveAction(ocptBudgetAmountLabel(30000, "EUR"));
      await tester.tap(find.widgetWithText(FilledButton, receiveLabel));
      expect(received?.id, "revenue-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFinancingEditAction));
      expect(edited?.id, "revenue-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetCommittedDeleteAction));
      expect(deletedId, "revenue-1");
    });
  });

  group("the receipt variant", () {
    testWidgets("reads the entry it names with a two-step stepper, rather than throwing", (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          testFiche(
            selection: const OcptBudgetReceiptSelection("entry-1"),
            entries: [buildEntry(creditCents: 4000, posteId: null, resourceId: "resource-1")],
            resources: [buildResource()],
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(tester.takeException(), isNull);
      expect(find.text("Region grant"), findsOneWidget);
      expect(find.text(tr.budgetFicheStepPromisedLabel), findsOneWidget);
      expect(find.text(tr.budgetFinancingColumnReceived), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsNWidgets(2));
    });

    testWidgets("shows the empty hint while the entry it would read has disappeared", (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(testFiche(selection: const OcptBudgetReceiptSelection("gone"))));

      expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
    });
  });
}
