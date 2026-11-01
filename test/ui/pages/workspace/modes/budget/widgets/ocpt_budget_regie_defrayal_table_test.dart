// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';
import 'ocpt_budget_regie_test_doubles.dart';

/// A minimal debit entry reimbursing [personId], everything else neutral.
OcptBudgetEntry _buildEntry({
  required String id,
  String? personId,
  int debitCents = 0,
  String label = "",
  DateTime? date,
}) => OcptBudgetEntry(
  id: id,
  date: date ?? DateTime(2026, 3),
  label: label,
  posteId: null,
  debitCents: debitCents,
  creditCents: 0,
  isTaxInclusive: true,
  vatRateBasisPoints: null,
  voucherNumber: "J-001",
  sortKey: "a0",
  resourceId: null,
  revenueId: null,
  shareId: null,
  commitmentId: null,
  personId: personId,
);

/// A minimal poste holding no line, offered by the provisioning band's own picker.
OcptBudgetPoste _buildPoste({required String id}) => OcptBudgetPoste(
  id: id,
  code: "6",
  label: "Régie",
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: const [],
);

void main() {
  /// Pumps [OcptBudgetRegie] with every callback a no-op unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<OcptBudgetRegieDay> days,
    List<OcptBudgetAllowance> allowances = const [],
    List<OcptBudgetEntry> entries = const [],
    Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId = const {},
    int? defaultVatRateBasisPoints,
    List<OcptBudgetPoste> postes = const [],
    String? provisionPosteId,
    int provisionedTotalCents = 0,
    Map<String, String> decorNameByDayId = const {},
    int? mealPriceCents,
    int? buffetPriceCents,
    List<OcptRole> roles = const [],
    List<OcptPerson> people = const [],
    int breakdownPricedElementCount = 0,
    int breakdownUnpricedElementCount = 0,
    bool isReadOnly = false,
    Set<String> expandedNodeIds = const {},
    ValueChanged<String>? onNodeExpansionToggled,
    ValueChanged<String>? onPersonOpenRequested,
    VoidCallback? onScheduleOpenRequested,
    VoidCallback? onBreakdownFeedRequested,
    VoidCallback? onProjectSettingsRequested,
    ValueChanged<String>? onAllowanceEditRequested,
    ValueChanged<String>? onAllowanceDeletionRequested,
    ValueChanged<String>? onPersonReimburseRequested,
    ValueChanged<String>? onProvisionPosteSelected,
    VoidCallback? onProvisionRequested,
    String? provisionNote,
    Size size = const Size(1400, 700),
  }) async {
    // The default test surface is narrower than `_ocptRegieWrapWidth`, which would silently
    // switch every test onto the stacked layout instead of the side-by-side one this suite means
    // to exercise — widened here so the wrapping `SizedBox` below isn't itself clamped down.
    tester.view.physicalSize = Size(size.width, size.height + 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(
        size: size,
        OcptBudgetRegie(
          days: days,
          cateringTotals: ocptBudgetRegieTotalsOf(days),
          decorNameByDayId: decorNameByDayId,
          mealPriceCents: mealPriceCents,
          buffetPriceCents: buffetPriceCents,
          allowances: allowances,
          entries: entries,
          reimbursedByPersonId: reimbursedByPersonId,
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          postes: postes,
          provisionPosteId: provisionPosteId,
          provisionedTotalCents: provisionedTotalCents,
          roles: roles,
          people: people,
          breakdownPricedElementCount: breakdownPricedElementCount,
          breakdownUnpricedElementCount: breakdownUnpricedElementCount,
          currencyCode: "EUR",
          isReadOnly: isReadOnly,
          expandedNodeIds: expandedNodeIds,
          onNodeExpansionToggled: onNodeExpansionToggled ?? (_) {},
          onAllowanceEditRequested: onAllowanceEditRequested ?? (_) {},
          onAllowanceDeletionRequested: onAllowanceDeletionRequested ?? (_) {},
          onPersonReimburseRequested: onPersonReimburseRequested ?? (_) {},
          onProvisionPosteSelected: onProvisionPosteSelected ?? (_) {},
          onProvisionRequested: onProvisionRequested ?? () {},
          provisionNote: provisionNote,
          onScheduleOpenRequested: onScheduleOpenRequested ?? () {},
          onBreakdownFeedRequested: onBreakdownFeedRequested ?? () {},
          onProjectSettingsRequested: onProjectSettingsRequested ?? () {},
          onPersonOpenRequested: onPersonOpenRequested ?? (_) {},
        ),
      ),
    );
  }

  group("the defrayal table is a tree grouped by person", () {
    testWidgets("a person group row shows what they have advanced, been reimbursed and are owed", (
      tester,
    ) async {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      await pumpView(
        tester,
        days: days,
        allowances: [buildAllowance(id: "a1", personId: "person-1", unitAmountMilliCents: 100000)],
        entries: [_buildEntry(id: "e1", personId: "person-1", debitCents: 40)],
        reimbursedByPersonId: const {
          "person-1": OcptBudgetCoveredTotal(amountCents: 40, coveredLineCount: 1, lineCount: 1),
        },
        people: [buildPerson(id: "person-1", firstName: "Alex")],
      );

      expect(find.text("Alex"), findsOneWidget);
      // 100 cents advanced, 40 reimbursed, 60 still owed — the group row's own running account,
      // read with no expansion needed.
      expect(find.text(ocptBudgetAmountLabel(100, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(40, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(60, "EUR")), findsWidgets);
    });

    testWidgets("expanding a person reveals their own defrayals, then their own reimbursements", (
      tester,
    ) async {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );
      final allowances = [
        buildAllowance(id: "a1", personId: "person-1", unitAmountMilliCents: 100000),
      ];
      final entries = [
        _buildEntry(id: "e1", personId: "person-1", debitCents: 40, label: "Refund"),
      ];
      final people = [buildPerson(id: "person-1", firstName: "Alex")];

      await pumpView(tester, days: days, allowances: allowances, entries: entries, people: people);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
      // Collapsed: neither sub-row draws.
      expect(find.textContaining(tr.budgetAllowanceKindTravelLabel), findsNothing);
      expect(find.textContaining("Refund"), findsNothing);

      await pumpView(
        tester,
        days: days,
        allowances: allowances,
        entries: entries,
        people: people,
        expandedNodeIds: const {"person-1"},
      );

      // Expanded: the defrayal's own detail line, then the reimbursement's own.
      expect(
        find.text("${tr.budgetAllowanceKindTravelLabel} · $ocptBudgetEmptyValue · ×1"),
        findsOneWidget,
      );
      expect(find.textContaining("Refund"), findsOneWidget);
    });

    testWidgets("a defrayal naming nobody is its own group of one, with no running account", (
      tester,
    ) async {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      await pumpView(
        tester,
        days: days,
        allowances: [buildAllowance(id: "a1", unitAmountMilliCents: 100000)],
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
      // Its own wording, no twisty to expand onto.
      expect(find.text(tr.budgetRegieAllowanceNoPerson), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      // ADVANCED and OWED both read its amount — it is owed in full, and the total row counts it
      // in, so it has to be legible on its own line — while REIMBURSED reads blank, no running
      // account named by a defrayal that belongs to nobody. The amount therefore appears at least
      // twice.
      expect(find.text(ocptBudgetAmountLabel(100, "EUR")), findsWidgets);
    });

    testWidgets("the total row sums every person's own advanced, reimbursed and owed", (
      tester,
    ) async {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      await pumpView(
        tester,
        days: days,
        allowances: [
          buildAllowance(id: "a1", personId: "person-1", unitAmountMilliCents: 100000),
          buildAllowance(id: "a2", unitAmountMilliCents: 50000),
        ],
        entries: [_buildEntry(id: "e1", personId: "person-1", debitCents: 40)],
        reimbursedByPersonId: const {
          "person-1": OcptBudgetCoveredTotal(amountCents: 40, coveredLineCount: 1, lineCount: 1),
        },
        people: [buildPerson(id: "person-1", firstName: "Alex")],
      );

      // 100 (person-1) + 50 (nobody) = 150 advanced, 40 reimbursed (the person-less defrayal names
      // no running account), 150 − 40 = 110 owed.
      // Note: neither the `TOTAL` label nor these figures are asserted `findsOneWidget` — the
      // catering table's own `Total` column header reads identically once uppercased, and the
      // provisioning band underneath both panes reads the very same computed total again, so more
      // than one match is expected here.
      expect(find.text(ocptBudgetAmountLabel(150, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(40, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(110, "EUR")), findsWidgets);
    });

    testWidgets("the person group row's own Rembourser is withheld under read-only", (
      tester,
    ) async {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );
      final allowances = [buildAllowance(id: "a1", personId: "person-1")];
      final people = [buildPerson(id: "person-1", firstName: "Alex")];

      await pumpView(tester, days: days, allowances: allowances, people: people);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetRegieReimburseAction), findsOneWidget);

      // Close the open menu before re-pumping read-only, so nothing from this pump lingers.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await pumpView(tester, days: days, allowances: allowances, people: people, isReadOnly: true);

      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetRegieReimburseAction), findsNothing);
      // Navigation, not a write: still offered under read-only.
      expect(find.text(tr.budgetRegieAllowanceOpenPersonAction), findsOneWidget);
    });
  });

  testWidgets("the provisioning band reads the gap between what is computed and what is quoted", (
    tester,
  ) async {
    final days = ocptBudgetRegieDaysOf(
      days: [buildDay(id: "day-1")],
      slotsByDayId: const {},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    await pumpView(
      tester,
      days: days,
      allowances: [buildAllowance(id: "allowance-1", quantityMilli: 168000)],
      postes: [_buildPoste(id: "poste-1")],
      provisionPosteId: "poste-1",
      provisionedTotalCents: 3000,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    expect(find.text(tr.budgetRegieProvisionComputedLabel.toUpperCase()), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(8887, "EUR")), findsWidgets);
    expect(find.text(ocptBudgetAmountLabel(3000, "EUR")), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(5887, "EUR")), findsOneWidget);
  });

  testWidgets("a provisioning that would do nothing says why in place of the button", (
    tester,
  ) async {
    // The reason sits beside the figures rather than behind a click: a gesture answering "no" is
    // withheld, and what a reader needs then is why.
    final days = ocptBudgetRegieDaysOf(
      days: [buildDay(id: "day-1")],
      slotsByDayId: const {},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    await pumpView(
      tester,
      days: days,
      postes: [_buildPoste(id: "poste-1")],
      provisionPosteId: "poste-1",
      provisionNote: "Nothing to provision.",
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    expect(find.text("Nothing to provision."), findsOneWidget);
    expect(find.text(tr.budgetRegieProvisionAction), findsNothing);
  });

  testWidgets("a quote with no poste says so instead of offering an inert picker", (tester) async {
    final days = ocptBudgetRegieDaysOf(
      days: [buildDay(id: "day-1")],
      slotsByDayId: const {},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    await pumpView(tester, days: days);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    expect(find.text(tr.budgetRegieProvisionNoPosteHint), findsOneWidget);
    expect(find.text(tr.budgetRegieProvisionAction), findsNothing);
  });

  testWidgets("every writing affordance is withheld under a previewed version", (tester) async {
    final days = ocptBudgetRegieDaysOf(
      days: [buildDay(id: "day-1")],
      slotsByDayId: const {},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    await pumpView(
      tester,
      days: days,
      allowances: [buildAllowance(id: "allowance-1")],
      postes: [_buildPoste(id: "poste-1")],
      provisionPosteId: "poste-1",
      isReadOnly: true,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    // Withheld, never disabled: the controls are not on screen at all.
    expect(find.text(tr.budgetRegieProvisionAction), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    // The reading itself is untouched — a version is still read.
    expect(find.text(tr.budgetRegieAllowanceNoPerson), findsOneWidget);
  });

  testWidgets("a project with defrayals but no shooting day keeps its layout", (tester) async {
    // The empty state is for a project holding neither, now that this view has a `+` action of its
    // own to keep a heading band drawn for.
    await pumpView(
      tester,
      days: const [],
      allowances: [buildAllowance(id: "allowance-1")],
    );

    expect(find.byType(OcptWorkspaceEmptyMode), findsNothing);
  });

  group("a view too short for its two panes", () {
    testWidgets("scrolls rather than crushing either table out of its own rows", (tester) async {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: {
          "day-1": [
            buildSlot(
              id: "slot-1",
              dayId: "day-1",
              crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-2")],
            ),
          ],
        },
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      // Narrow enough to stack the two panes, and short enough that a third of what is left is
      // under either pane's own floor — the geometry that used to leave both `ListView`s nothing
      // at all, print a header and a total with no row between them, and then spill the catering
      // pane over the defrayals underneath it.
      await pumpView(
        tester,
        days: days,
        allowances: [buildAllowance(id: "allowance-1", personId: "person-1")],
        people: [buildPerson(id: "person-1", firstName: "Marie")],
        size: const Size(800, 420),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
      // Both tables still hold their row: the day's own tag, and the defrayal's own person.
      expect(find.text(ocptScheduleDayTagLabel(tr, 1)), findsOneWidget);
      expect(find.text("Marie"), findsOneWidget);
      // And the pair is reachable, rather than clipped: the view scrolls vertically.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
        ),
        findsWidgets,
      );
    });

    testWidgets("a roomy view is not made to scroll for nothing", (tester) async {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      await pumpView(tester, days: days, size: const Size(1400, 900));

      final scroller = tester.widget<SingleChildScrollView>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
            )
            .first,
      );
      final box = tester.renderObject<RenderBox>(find.byWidget(scroller));
      final content = tester.renderObject<RenderBox>(
        find.descendant(of: find.byWidget(scroller), matching: find.byType(SizedBox)).first,
      );

      // The panes are handed the view's own height, not their floors added up.
      expect(content.size.height, box.size.height);
    });
  });
}
