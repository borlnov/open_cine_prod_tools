// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_committed_spending.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that the whole table is drawn with no scroll needed to find a cell.
Widget _wrap(Widget child, {Size size = const Size(1400, 700)}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: size.width, height: size.height, child: child)),
);

/// A minimal poste, everything but [id]/[label] neutral.
OcptBudgetPoste _poste({required String id, required String label}) =>
    OcptBudgetPoste(id: id, code: "1", label: label, simpleLabel: null, estimateToCompleteCents: null, sortKey: "a0", lines: const []);

/// A minimal commitment, everything but what each test actually varies neutral.
OcptBudgetCommitment _commitment({
  required String id,
  DateTime? dueDate,
  String label = "Camera rental",
  String posteId = "poste-1",
  int amountCents = 1000,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
  String? settledEntryId,
  String sortKey = "a0",
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: label,
  posteId: posteId,
  amount: OcptMoney(
    amountCents: amountCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  status: status,
  settledEntryId: settledEntryId,
  lineId: null,
  sortKey: sortKey,
);

void main() {
  /// Pumps [OcptBudgetCommittedSpending] with every callback a no-op unless overridden.
  ///
  /// [allCommitments] defaults to empty — never the same list as [commitments] — so a test that
  /// says nothing about the projection gets none, exactly as it read before this widget took the
  /// projection back: only a test that means to exercise it passes one.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<OcptBudgetCommitment> commitments,
    List<OcptBudgetCommitment> allCommitments = const [],
    List<OcptBudgetPoste> postes = const [],
    int? defaultVatRateBasisPoints,
    int openingBalanceCents = 0,
    bool isReadOnly = false,
    VoidCallback? onCommitmentCreationRequested,
    ValueChanged<OcptBudgetCommitment>? onCommitmentTapped,
    ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested,
    ValueChanged<String>? onCommitmentUnsettleRequested,
    ValueChanged<String>? onCommitmentDeletionRequested,
    Size size = const Size(1400, 700),
  }) async {
    await tester.pumpWidget(
      _wrap(
        size: size,
        OcptBudgetCommittedSpending(
          commitments: commitments,
          allCommitments: allCommitments,
          postes: postes,
          isSimplified: false,
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          currencyCode: "EUR",
          openingBalanceCents: openingBalanceCents,
          isReadOnly: isReadOnly,
          onCommitmentCreationRequested: onCommitmentCreationRequested ?? () {},
          onCommitmentTapped: onCommitmentTapped ?? (_) {},
          onCommitmentSettleRequested: onCommitmentSettleRequested ?? (_) {},
          onCommitmentUnsettleRequested: onCommitmentUnsettleRequested ?? (_) {},
          onCommitmentDeletionRequested: onCommitmentDeletionRequested ?? (_) {},
        ),
      ),
    );
  }

  testWidgets("a project with no commitment at all shows the shared empty state", (tester) async {
    await pumpView(tester, commitments: const []);

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets("an empty list still offers the action that fills it", (tester) async {
    var created = 0;

    await pumpView(
      tester,
      commitments: const [],
      onCommitmentCreationRequested: () => created++,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
    await tester.tap(find.text(tr.budgetCommittedCreationAction));

    expect(created, 1);
  });

  testWidgets(
    "a settled commitment stays listed but is excluded from the outstanding total",
    (tester) async {
      final commitments = [
        _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 5000, status: OcptBudgetCommitmentStatus.declared),
        _commitment(id: "c2", dueDate: DateTime(2026, 1, 2), amountCents: 2000, settledEntryId: "entry-1"),
      ];

      await pumpView(tester, commitments: commitments);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
      // Both rows are drawn — the settled one is history worth keeping.
      expect(find.text("Camera rental"), findsNWidgets(2));
      expect(find.text(tr.budgetCommittedStatusSettledLabel), findsOneWidget);

      // The outstanding total counts only the unsettled 5000, not 7000.
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(7000, "EUR")), findsNothing);
    },
  );

  testWidgets(
    "a commitment that cannot be read tax-inclusive prints the em dash, but still counts towards "
    "the coverage read-out",
    (tester) async {
      final commitments = [
        _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 2000),
        _commitment(id: "c2", dueDate: DateTime(2026, 1, 2), isTaxInclusive: false),
      ];

      // Both commitments name a poste this view can resolve, so the only em dash left on screen is
      // the one this test is actually about: the unreadable commitment's own `Amount` cell. A row
      // whose poste is missing prints one in its `Poste` cell too, which would count here.
      await pumpView(
        tester,
        commitments: commitments,
        postes: [_poste(id: "poste-1", label: "Camera")],
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
      expect(find.text(ocptBudgetEmptyValue), findsOneWidget);
      // The outstanding total's own coverage read-out says 1 of the 2 commitments covers.
      expect(find.text(tr.budgetCommittedCoverageReadOut(1, 2)), findsOneWidget);
    },
  );

  testWidgets("an undated commitment is listed last, reading its own placeholder label", (
    tester,
  ) async {
    // Handed in already in the order `OcptBudgetJournalService.loadCommitments` would give them
    // (dated first, undated last) — this view never reorders its own input.
    final commitments = [
      _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 500),
      _commitment(id: "c2", amountCents: 1500),
    ];

    await pumpView(tester, commitments: commitments);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
    expect(find.text(tr.budgetCommittedNoDueDateLabel), findsOneWidget);
  });

  testWidgets("withholds every writing affordance under a previewed version", (tester) async {
    var tapped = false;
    final commitments = [_commitment(id: "c1", dueDate: DateTime(2026))];

    await pumpView(
      tester,
      commitments: commitments,
      isReadOnly: true,
      onCommitmentCreationRequested: () => tapped = true,
      onCommitmentTapped: (_) => tapped = true,
      onCommitmentSettleRequested: (_) => tapped = true,
      onCommitmentUnsettleRequested: (_) => tapped = true,
      onCommitmentDeletionRequested: (_) => tapped = true,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
    expect(
      find.widgetWithText(FilledButton, tr.budgetCommittedCreationAction),
      findsNothing,
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    await tester.tap(find.text("Camera rental"));
    await tester.pumpAndSettle();
    expect(tapped, isFalse);
  });

  group("the cash projection", () {
    testWidgets("drawn beside the table while at least one commitment is unsettled", (
      tester,
    ) async {
      await pumpView(
        tester,
        commitments: [_commitment(id: "c1", dueDate: DateTime(2026))],
        allCommitments: [_commitment(id: "c1", dueDate: DateTime(2026))],
        openingBalanceCents: 5000,
      );

      expect(find.byKey(const Key("ocptBudgetCashProjectionToggle")), findsOneWidget);
    });

    testWidgets("withheld while every commitment is settled", (tester) async {
      await pumpView(
        tester,
        commitments: [_commitment(id: "c1", dueDate: DateTime(2026))],
        allCommitments: [_commitment(id: "c1", dueDate: DateTime(2026), settledEntryId: "entry-1")],
        openingBalanceCents: 5000,
      );

      expect(find.byKey(const Key("ocptBudgetCashProjectionToggle")), findsNothing);
    });

    testWidgets("withheld while the project carries no commitment at all", (tester) async {
      await pumpView(tester, commitments: const [], openingBalanceCents: 5000);

      expect(find.byKey(const Key("ocptBudgetCashProjectionToggle")), findsNothing);
    });

    testWidgets(
      "reads every commitment, even one the poste filter left out of the table",
      (tester) async {
        // The table itself is filtered down to nothing — its own empty state draws — while the
        // project still holds an unsettled commitment elsewhere, which the projection reads
        // regardless: `allCommitments` is never narrowed by the poste filter.
        await pumpView(
          tester,
          commitments: const [],
          allCommitments: [_commitment(id: "c1", dueDate: DateTime(2026))],
          openingBalanceCents: 5000,
        );

        expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
        expect(find.byKey(const Key("ocptBudgetCashProjectionToggle")), findsOneWidget);
      },
    );
  });

  testWidgets("the table scrolls sideways rather than overflowing a narrow centre", (tester) async {
    // Narrow enough that the table's own fixed columns plus its floor for the wording no longer
    // fit — the geometry `_ocptCommittedMinTableWidth` guards against.
    await pumpView(
      tester,
      commitments: [_commitment(id: "c1", amountCents: 120000)],
      size: const Size(600, 700),
    );

    expect(tester.takeException(), isNull);
    expect(find.text("Camera rental"), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
  });

  group("the expanded projection never overflows its column", () {
    // Enough commitments that the card, expanded, is taller than the pane it is drawn in — the
    // geometry `_ocptCommittedStackedProjectionMaxShare` and the two scroll views guard against.
    // A `Column` of steps in a pane with a height of its own overflows rather than scrolling, and
    // a release build paints no overflow band to say so.
    final crowded = [
      for (var index = 0; index < 14; index++)
        _commitment(
          id: "c$index",
          dueDate: DateTime(2026).add(Duration(days: index * 7)),
          amountCents: 100000,
        ),
    ];

    for (final (name, size) in [
      ("side by side, tall", const Size(1400, 700)),
      ("side by side, short", const Size(1400, 420)),
      ("stacked, tall", const Size(900, 700)),
      ("stacked, short", const Size(900, 420)),
    ]) {
      testWidgets(name, (tester) async {
        await pumpView(
          tester,
          commitments: crowded,
          allCommitments: crowded,
          openingBalanceCents: 500000,
          size: size,
        );

        await tester.tap(find.byKey(const Key("ocptBudgetCashProjectionToggle")));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
