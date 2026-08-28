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
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band wide
/// enough that every field of the fiche is drawn with no overflow.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 420, height: 1400, child: child)),
);

/// Grows the test surface tall enough that every one of the fiche's own actions sits inside the
/// hit-testable area — the fiche's own body scrolls, but the surface itself still has to be at
/// least as tall as what a test means to tap.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A `fieldValueOf` reading every field straight off its own stored value — no pending edit ever
/// overrides it, which is all these tests need.
String _storedFieldValueOf(String targetId, OcptBudgetField field, String storedValue) => storedValue;

/// A quote line priced at 10.00 €, tax-inclusive, pricing no breakdown element.
const _line = OcptBudgetLine(
  id: "line-1",
  posteId: "poste-1",
  label: "Crown",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(amountCents: 1000, isTaxInclusive: true, vatRateBasisPoints: null),
  elementId: null,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// The poste every test below reads, holding [_line] alone.
const _poste = OcptBudgetPoste(
  id: "poste-1",
  code: "5",
  label: "Sets and costumes",
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: [_line],
);

/// Builds a commitment against [_poste], everything but what a test actually varies neutral —
/// settlement is read off whichever entries the test hands in alongside it, never a field of the
/// commitment itself any more.
OcptBudgetCommitment _buildCommitment({
  String id = "commitment-1",
  String? lineId,
  int amountCents = 1000,
  DateTime? dueDate,
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: "Glass workshop",
  posteId: "poste-1",
  amount: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  status: OcptBudgetCommitmentStatus.invoiceReceived,
  lineId: lineId,
  sortKey: "a0",
);

/// Builds a journal entry, everything but what a test actually varies neutral.
OcptBudgetEntry _buildEntry({
  String id = "entry-1",
  String? posteId = "poste-1",
  int debitCents = 0,
  int creditCents = 0,
  String? resourceId,
  String? revenueId,
  String? commitmentId,
}) => OcptBudgetEntry(
  id: id,
  date: DateTime(2026, 8, 18),
  label: "Invoice",
  posteId: posteId,
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: true,
  vatRateBasisPoints: null,
  voucherNumber: "J-001",
  sortKey: "a0",
  resourceId: resourceId,
  revenueId: revenueId,
  shareId: null,
  commitmentId: commitmentId,
  personId: null,
);

/// Builds a financing resource, everything but what a test actually varies neutral.
OcptBudgetResource _buildResource({
  String id = "resource-1",
  OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.cash,
  int amountCents = 200000,
  OcptBudgetResourceStatus status = OcptBudgetResourceStatus.agreed,
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  personId: null,
  label: "Region grant",
  amountCents: amountCents,
  status: status,
  isReimbursable: false,
  notes: "",
  sortKey: "a0",
);

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

/// The fiche's own no-op parameters, spread across every test below so each only overrides what it
/// actually cares about.
OcptBudgetFiche _fiche({
  OcptBudgetSelection? selection,
  List<OcptBudgetPoste> postes = const [_poste],
  List<OcptBudgetCommitment> commitments = const [],
  List<OcptBudgetEntry> entries = const [],
  List<OcptBudgetResource> resources = const [],
  List<OcptBudgetRevenue> revenues = const [],
  bool isReadOnly = false,
  Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
  Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
  ValueChanged<String>? onLineCommitRequested,
  ValueChanged<String>? onLinePayDirectlyRequested,
  ValueChanged<String>? onLineSettleRequested,
  ValueChanged<String>? onLineShowCommitmentRequested,
  ValueChanged<String>? onLineUncommitRequested,
  ValueChanged<String>? onLineDeletionRequested,
  ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested,
  ValueChanged<OcptBudgetCommitment>? onCommitmentEditRequested,
  ValueChanged<String>? onCommitmentDeletionRequested,
  VoidCallback? onCommitmentPromoteToQuoteRequested,
  ValueChanged<OcptBudgetEntry>? onEntryEditRequested,
  ValueChanged<String>? onEntryDeletionRequested,
  VoidCallback? onEntryPromoteToQuoteRequested,
  VoidCallback? onEntryMoveOffQuoteRequested,
  ValueChanged<OcptBudgetResource>? onResourceReceiptRequested,
  ValueChanged<OcptBudgetResource>? onResourceEditRequested,
  ValueChanged<String>? onResourceDeletionRequested,
  ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested,
  ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested,
  ValueChanged<String>? onRevenueDeletionRequested,
}) => OcptBudgetFiche(
  selection: selection,
  postes: postes,
  commitments: commitments,
  entries: entries,
  resources: resources,
  revenues: revenues,
  taxBasis: OcptBudgetTaxBasis.includingTax,
  defaultVatRateBasisPoints: null,
  currencyCode: "EUR",
  isSimplified: false,
  isReadOnly: isReadOnly,
  elementNameByElementId: const {},
  receiptsByEntryId: const {},
  receivedByResourceId: receivedByResourceId,
  receivedByRevenueId: receivedByRevenueId,
  fieldValueOf: _storedFieldValueOf,
  onFieldChanged: (_, __, ___) {},
  onPosteEstimateToCompleteDerivedRequested: (_) {},
  onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
  onLineVatRateInheritedRequested: (_) {},
  onLineCommitRequested: onLineCommitRequested,
  onLinePayDirectlyRequested: onLinePayDirectlyRequested,
  onLineSettleRequested: onLineSettleRequested,
  onLineShowCommitmentRequested: onLineShowCommitmentRequested,
  onLineUncommitRequested: onLineUncommitRequested,
  onLineDeletionRequested: onLineDeletionRequested,
  onCommitmentSettleRequested: onCommitmentSettleRequested,
  onCommitmentEditRequested: onCommitmentEditRequested,
  onCommitmentDeletionRequested: onCommitmentDeletionRequested,
  onCommitmentPromoteToQuoteRequested: onCommitmentPromoteToQuoteRequested,
  onEntryEditRequested: onEntryEditRequested,
  onEntryDeletionRequested: onEntryDeletionRequested,
  onEntryPromoteToQuoteRequested: onEntryPromoteToQuoteRequested,
  onEntryMoveOffQuoteRequested: onEntryMoveOffQuoteRequested,
  onResourceReceiptRequested: onResourceReceiptRequested,
  onResourceEditRequested: onResourceEditRequested,
  onResourceDeletionRequested: onResourceDeletionRequested,
  onRevenueReceiptRequested: onRevenueReceiptRequested,
  onRevenueEditRequested: onRevenueEditRequested,
  onRevenueDeletionRequested: onRevenueDeletionRequested,
);

void main() {
  testWidgets("shows the empty hint while nothing is selected", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(_fiche()));

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets("shows the empty hint while the selection names a row that has since disappeared", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_fiche(selection: const OcptBudgetPosteSelection("gone"), postes: const [])),
    );

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  group("the poste variant", () {
    testWidgets(
      "shows the breadcrumb, the six figures, the remaining amount and the editable fields",
      (tester) async {
        await tester.pumpWidget(
          _wrap(_fiche(selection: const OcptBudgetPosteSelection("poste-1"))),
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
      await tester.pumpWidget(_wrap(_fiche(selection: const OcptBudgetPosteSelection("poste-1"))));

      // The bar's own track: a Container of the proportion bar's own height, stretched to fill the
      // width the fiche gives it rather than a fixed one — on the 420-wide test surface it comes out
      // well past the 160 an earlier fixed pass drew, which is the whole point of the change.
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
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(_fiche(selection: const OcptBudgetPosteSelection("poste-1"))),
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
        _wrap(
          _fiche(
            selection: const OcptBudgetPosteSelection("poste-1"),
            postes: const [_poste, otherPoste],
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
        _wrap(_fiche(selection: const OcptBudgetPosteSelection("poste-1"))),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text(tr.budgetInspectorPosteCodeDuplicateError), findsNothing);
    });
  });

  group("the quote line variant", () {
    testWidgets("not promoted: Pay is primary, Commit and Delete the secondaries", (tester) async {
      _useTallSurface(tester);
      String? paidLineId;
      String? committedLineId;
      String? deletedLineId;
      await tester.pumpWidget(
        _wrap(
          _fiche(
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
        find.widgetWithText(FilledButton, tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR"))),
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
      _useTallSurface(tester);
      String? settledLineId;
      String? shownLineId;
      String? uncommittedLineId;
      await tester.pumpWidget(
        _wrap(
          _fiche(
            selection: const OcptBudgetLineSelection("line-1"),
            commitments: [_buildCommitment(lineId: "line-1")],
            onLineSettleRequested: (lineId) => settledLineId = lineId,
            onLineShowCommitmentRequested: (lineId) => shownLineId = lineId,
            onLineUncommitRequested: (lineId) => uncommittedLineId = lineId,
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.byIcon(Icons.circle), findsNWidgets(2));
      expect(
        find.widgetWithText(FilledButton, tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR"))),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR"))),
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

    testWidgets(
      "promoted, part-paid: Pay offers the outstanding, not the full commitment, and the "
      "payments section lists the instalment",
      (tester) async {
        _useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetLineSelection("line-1"),
              commitments: [_buildCommitment(lineId: "line-1")],
              entries: [_buildEntry(debitCents: 400, commitmentId: "commitment-1")],
              onLineSettleRequested: (_) {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        // Outstanding is 1000 - 400 = 600, not the commitment's own full 1000.
        final payLabel = tr.budgetFichePayAction(ocptBudgetAmountLabel(600, "EUR"));
        expect(find.widgetWithText(FilledButton, payLabel), findsOneWidget);
        expect(find.text(ocptBudgetAmountLabel(600, "EUR")), findsWidgets);
        expect(find.widgetWithText(FilledButton, tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR"))), findsNothing);

        // The payments section lists the one instalment paid so far.
        expect(find.text(tr.budgetFicheCommitmentPaymentsSectionTitle.toUpperCase()), findsOneWidget);
        expect(find.text(ocptBudgetAmountLabel(400, "EUR")), findsWidgets);
      },
    );

    testWidgets("the payments section lists every instalment, oldest first", (tester) async {
      _useTallSurface(tester);
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
        _wrap(
          _fiche(
            selection: const OcptBudgetLineSelection("line-1"),
            commitments: [_buildCommitment(lineId: "line-1")],
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

    testWidgets("promoted, settled: no primary, Delete is the only secondary", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _fiche(
            selection: const OcptBudgetLineSelection("line-1"),
            commitments: [_buildCommitment(lineId: "line-1")],
            entries: [_buildEntry(debitCents: 1000, commitmentId: "commitment-1")],
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
  });

  group("the commitment variant", () {
    testWidgets("unsettled: Pay is primary, Edit and Delete are the two secondaries", (
      tester,
    ) async {
      _useTallSurface(tester);
      OcptBudgetCommitment? settled;
      OcptBudgetCommitment? edited;
      String? deletedId;
      final commitment = _buildCommitment(amountCents: 25000);

      await tester.pumpWidget(
        _wrap(
          _fiche(
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
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          _fiche(
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
            commitments: [_buildCommitment()],
            entries: [_buildEntry(debitCents: 400, commitmentId: "commitment-1")],
            onCommitmentSettleRequested: (_) {},
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      // Outstanding is 1000 - 400 = 600, not the commitment's own full 1000 — the same reading the
      // promoted quote line's own fiche already offers.
      expect(
        find.widgetWithText(FilledButton, tr.budgetFichePayAction(ocptBudgetAmountLabel(600, "EUR"))),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, tr.budgetFichePayAction(ocptBudgetAmountLabel(1000, "EUR"))),
        findsNothing,
      );
    });

    testWidgets("settled: no primary, and the outstanding block reads the em dash", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _fiche(
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
            commitments: [_buildCommitment()],
            entries: [_buildEntry(debitCents: 1000, commitmentId: "commitment-1")],
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
        _wrap(
          _fiche(
            selection: const OcptBudgetCommitmentSelection("commitment-1"),
            commitments: [_buildCommitment(lineId: "line-1")],
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

      expect(find.text("5 Sets and costumes"), findsOneWidget);
      expect(find.text("Crown"), findsOneWidget);
      expect(find.text(tr.budgetFicheKindCommitmentLabel), findsOneWidget);
    });
  });

  group("the entry variant", () {
    testWidgets("Edit is primary, Delete the only secondary, and it carries no outstanding", (
      tester,
    ) async {
      _useTallSurface(tester);
      OcptBudgetEntry? edited;
      String? deletedId;
      await tester.pumpWidget(
        _wrap(
          _fiche(
            selection: const OcptBudgetEntrySelection("entry-1"),
            entries: [_buildEntry(debitCents: 5000)],
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
        _wrap(
          _fiche(
            selection: const OcptBudgetEntrySelection("entry-1"),
            entries: [_buildEntry(debitCents: 5000)],
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
          _useTallSurface(tester);
          var promoted = false;
          var movedOffQuote = false;
          await tester.pumpWidget(
            _wrap(
              _fiche(
                selection: const OcptBudgetEntrySelection("entry-1"),
                // 500 against the poste's own 1,000 quote — not over, so no overrun clause.
                entries: [_buildEntry(debitCents: 500)],
                onEntryPromoteToQuoteRequested: () => promoted = true,
                onEntryMoveOffQuoteRequested: () => movedOffQuote = true,
              ),
            ),
          );
          final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

          expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsOneWidget);

          await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction));
          expect(promoted, isTrue);

          await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFicheEntryMoveOffQuoteAction));
          expect(movedOffQuote, isTrue);
        },
      );

      testWidgets("states the poste's own overrun once it is over its quote", (tester) async {
        _useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              // 5,000 against the poste's own 1,000 quote — 4,000 over.
              entries: [_buildEntry(debitCents: 5000)],
              onEntryPromoteToQuoteRequested: () {},
              onEntryMoveOffQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(
          find.text(tr.budgetFicheEntryOffLineBannerOverQuoteText(ocptBudgetAmountLabel(4000, "EUR"))),
          findsOneWidget,
        );
        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsNothing);
      });

      testWidgets("withholds both actions under a previewed version, the text stays", (tester) async {
        _useTallSurface(tester);
        var written = false;
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [_buildEntry(debitCents: 500)],
              isReadOnly: true,
              onEntryPromoteToQuoteRequested: () => written = true,
              onEntryMoveOffQuoteRequested: () => written = true,
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction), findsNothing);
        expect(find.widgetWithText(OutlinedButton, tr.budgetFicheEntryMoveOffQuoteAction), findsNothing);
        expect(written, isFalse);
      });

      testWidgets("does not show once the entry already names a commitment", (tester) async {
        _useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [_buildEntry(debitCents: 500, commitmentId: "commitment-1")],
              commitments: [_buildCommitment()],
              onEntryPromoteToQuoteRequested: () {},
              onEntryMoveOffQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsNothing);
      });

      testWidgets("does not show on a credit", (tester) async {
        _useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [_buildEntry(creditCents: 500)],
              onEntryPromoteToQuoteRequested: () {},
              onEntryMoveOffQuoteRequested: () {},
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheEntryOffLineBannerText), findsNothing);
      });

      testWidgets("does not show on a debit naming no poste at all", (tester) async {
        _useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetEntrySelection("entry-1"),
              entries: [_buildEntry(posteId: null, debitCents: 500)],
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
        _useTallSurface(tester);
        var promoted = false;
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              // 1,000, matching the poste's own 1,000 quote — not over, so no overrun clause.
              commitments: [_buildCommitment()],
              onCommitmentPromoteToQuoteRequested: () => promoted = true,
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheCommitmentOffLineBannerText), findsOneWidget);
        // The one thing a commitment cannot do: it always names a poste, so no Move off-quote.
        expect(find.widgetWithText(OutlinedButton, tr.budgetFicheEntryMoveOffQuoteAction), findsNothing);

        await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction));
        expect(promoted, isTrue);
      });

      testWidgets("states the poste's own overrun once it is over its quote", (tester) async {
        _useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              // 5,000 committed against the poste's own 1,000 quote — 4,000 over.
              commitments: [_buildCommitment(amountCents: 5000)],
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
        _useTallSurface(tester);
        var written = false;
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              commitments: [_buildCommitment()],
              isReadOnly: true,
              onCommitmentPromoteToQuoteRequested: () => written = true,
            ),
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptBudgetFiche)));

        expect(find.text(tr.budgetFicheCommitmentOffLineBannerText), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, tr.budgetFichePromoteToQuoteAction), findsNothing);
        expect(written, isFalse);
      });

      testWidgets("does not show once the commitment already names a line", (tester) async {
        _useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetCommitmentSelection("commitment-1"),
              commitments: [_buildCommitment(lineId: "line-1")],
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
      _useTallSurface(tester);
      OcptBudgetResource? received;
      OcptBudgetResource? edited;
      String? deletedId;
      final resource = _buildResource();

      await tester.pumpWidget(
        _wrap(
          _fiche(
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
      "an in-kind resource no entry names reads the em dash for Received and Outstanding, "
      "and offers no Receive action",
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _fiche(
              selection: const OcptBudgetResourceSelection("resource-1"),
              resources: [_buildResource(groupKind: OcptBudgetResourceGroupKind.inKind)],
              onResourceReceiptRequested: (_) {},
            ),
          ),
        );

        expect(find.byType(FilledButton), findsNothing);
        expect(find.text(ocptBudgetEmptyValue), findsWidgets);
      },
    );

    testWidgets("withholds Receive once the resource is fully received", (tester) async {
      await tester.pumpWidget(
        _wrap(
          _fiche(
            selection: const OcptBudgetResourceSelection("resource-1"),
            resources: [_buildResource(amountCents: 50000)],
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
      _useTallSurface(tester);
      OcptBudgetRevenue? received;
      OcptBudgetRevenue? edited;
      String? deletedId;
      final revenue = _buildRevenue();

      await tester.pumpWidget(
        _wrap(
          _fiche(
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
      expect(
        find.text(ocptBudgetRevenueStatusLabel(tr, revenue.status)),
        findsOneWidget,
      );

      final receiveLabel = tr.budgetFicheReceiveAction(ocptBudgetAmountLabel(30000, "EUR"));
      await tester.tap(find.widgetWithText(FilledButton, receiveLabel));
      expect(received?.id, "revenue-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetFinancingEditAction));
      expect(edited?.id, "revenue-1");

      await tester.tap(find.widgetWithText(OutlinedButton, tr.budgetCommittedDeleteAction));
      expect(deletedId, "revenue-1");
    });
  });

  group("the receipt variant (M6 wires the selection itself)", () {
    testWidgets("reads the entry it names with a two-step stepper, rather than throwing", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _fiche(
            selection: const OcptBudgetReceiptSelection("entry-1"),
            entries: [_buildEntry(creditCents: 4000, posteId: null, resourceId: "resource-1")],
            resources: [_buildResource()],
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
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(_fiche(selection: const OcptBudgetReceiptSelection("gone"))),
      );

      expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
    });
  });
}
