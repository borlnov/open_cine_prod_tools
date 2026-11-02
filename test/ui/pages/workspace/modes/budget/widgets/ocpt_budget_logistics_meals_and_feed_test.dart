// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'ocpt_budget_logistics_test_doubles.dart';

/// Builds a cast convocation naming [roleId], the few fields these tests read.
OcptShootingSlotCastMember _buildCastMember({
  required String id,
  required String slotId,
  required String roleId,
}) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

/// Builds a guest attendance naming [personId], the few fields these tests read.
OcptShootingSlotGuest _buildGuest({
  required String id,
  required String slotId,
  required String personId,
}) => OcptShootingSlotGuest(
  id: id,
  slotId: slotId,
  personId: personId,
  freeName: "",
  reason: "",
  notes: "",
);

/// Builds a meal block on [slotId], the few fields these tests read.
OcptShootingDayBlock _buildMealBlock({
  required String id,
  required String dayId,
  required String slotId,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: dayId,
  slotId: slotId,
  kind: OcptShootingBlockKind.meal,
  shotId: null,
  sceneId: null,
  candidates: const [],
  label: "",
  durationMinutes: null,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

/// Run the tests of the budget logistics meals and feed.
void main() {
  /// Pumps [OcptBudgetLogistics] with every callback a no-op unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<OcptBudgetLogisticsDay> days,
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
    // The default test surface is narrower than `_ocptLogisticsWrapWidth`, which would silently
    // switch every test onto the stacked layout instead of the side-by-side one this suite means
    // to exercise — widened here so the wrapping `SizedBox` below isn't itself clamped down.
    tester.view.physicalSize = Size(size.width, size.height + 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(
        size: size,
        OcptBudgetLogistics(
          days: days,
          cateringTotals: ocptBudgetLogisticsTotalsOf(days),
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

  testWidgets("a project with no shooting day at all shows the shared empty state", (tester) async {
    await pumpView(tester, days: const []);

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
    // The feed card is drawn above the empty state too — see the class doc comment.
    expect(find.byType(OcptBudgetFeedCard), findsOneWidget);
  });

  group("the feed card", () {
    testWidgets("sits at the top, above the two columns, its own catering row withheld", (
      tester,
    ) async {
      final days = ocptBudgetLogisticsDaysOf(
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
        breakdownPricedElementCount: 3,
        breakdownUnpricedElementCount: 2,
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetLogistics)));
      expect(find.byType(OcptBudgetFeedCard), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedBreakdownReadOut(3, 5)), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedScheduleReadOut(days.length)), findsOneWidget);
      // Withheld — this very page is what the catering row would have named.
      expect(find.text(tr.budgetDashboardFeedCateringTitle), findsNothing);
    });

    testWidgets("its breakdown and schedule rows each report their own click", (tester) async {
      final days = ocptBudgetLogisticsDaysOf(
        days: [buildDay(id: "day-1")],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );
      var breakdownRequested = false;
      var scheduleRequested = false;

      await pumpView(
        tester,
        days: days,
        onBreakdownFeedRequested: () => breakdownRequested = true,
        onScheduleOpenRequested: () => scheduleRequested = true,
      );

      // The schedule row reports through `onScheduleOpenRequested` — the very callback the
      // catering column's own caption link already carries, both being the same request.
      final tr = Tr.of(tester.element(find.byType(OcptBudgetLogistics)));
      await tester.tap(find.text(tr.budgetDashboardFeedBreakdownTitle));
      await tester.tap(find.text(tr.budgetDashboardFeedScheduleTitle));
      await tester.pumpAndSettle();

      expect(breakdownRequested, isTrue);
      expect(scheduleRequested, isTrue);
    });
  });

  testWidgets(
    "a day's buffet count is rendered from its slots, a person convoked to three slots counted "
    "once",
    (tester) async {
      final day = buildDay(id: "day-1");
      final slots = [
        buildSlot(
          id: "slot-1",
          dayId: "day-1",
          crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
        ),
        buildSlot(
          id: "slot-2",
          dayId: "day-1",
          crew: [buildCrewMember(id: "crew-2", slotId: "slot-2", personId: "person-1")],
        ),
        buildSlot(
          id: "slot-3",
          dayId: "day-1",
          crew: [buildCrewMember(id: "crew-3", slotId: "slot-3", personId: "person-1")],
        ),
      ];

      final days = ocptBudgetLogisticsDaysOf(
        days: [day],
        slotsByDayId: {"day-1": slots},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      await pumpView(tester, days: days);

      // The crew column reads 1, not 3: the same person on three slots of one day still eats once.
      expect(find.text("1"), findsWidgets);
      expect(find.text("3"), findsNothing);
    },
  );

  testWidgets("a role of kind extra lands in the Extras column, not Cast", (tester) async {
    final day = buildDay(id: "day-1");
    final slot = buildSlot(
      id: "slot-1",
      dayId: "day-1",
      cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-extra")],
    );

    final days = ocptBudgetLogisticsDaysOf(
      days: [day],
      slotsByDayId: {
        "day-1": [slot],
      },
      blocksByDayId: const {},
      roleKindById: const {"role-extra": OcptRoleKind.extra},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    await pumpView(tester, days: days);

    expect(days.single.castCount, 0);
    expect(days.single.extraCount, 1);
  });

  testWidgets("a guest attending a slot changes no count", (tester) async {
    final day = buildDay(id: "day-1");
    final slotWithoutGuest = buildSlot(id: "slot-1", dayId: "day-1");
    final slotWithGuest = buildSlot(
      id: "slot-2",
      dayId: "day-1",
      guests: [_buildGuest(id: "guest-1", slotId: "slot-2", personId: "person-visitor")],
    );

    final withoutGuest = ocptBudgetLogisticsDaysOf(
      days: [day],
      slotsByDayId: {
        "day-1": [slotWithoutGuest],
      },
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );
    final withGuest = ocptBudgetLogisticsDaysOf(
      days: [day],
      slotsByDayId: {
        "day-1": [slotWithGuest],
      },
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    expect(withGuest.single.buffetCount, withoutGuest.single.buffetCount);
    expect(withGuest.single.buffetCount, 0);
  });

  testWidgets("a day with no meal block reads a dash in the Meals column, not a zero", (
    tester,
  ) async {
    final day = buildDay(id: "day-1");
    final slot = buildSlot(
      id: "slot-1",
      dayId: "day-1",
      crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
    );

    final days = ocptBudgetLogisticsDaysOf(
      days: [day],
      slotsByDayId: {
        "day-1": [slot],
      },
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: 1500,
      buffetPriceCents: null,
    );

    await pumpView(tester, days: days, mealPriceCents: 1500);

    expect(days.single.mealSittings, isEmpty);
    expect(find.text(ocptBudgetEmptyValue), findsWidgets);
  });

  testWidgets("a slot with a lunch and a dinner block joins both sittings in the Meals column", (
    tester,
  ) async {
    final day = buildDay(id: "day-1");
    final slot = buildSlot(
      id: "slot-1",
      dayId: "day-1",
      crew: [
        buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1"),
        buildCrewMember(id: "crew-2", slotId: "slot-1", personId: "person-2"),
      ],
    );

    final days = ocptBudgetLogisticsDaysOf(
      days: [day],
      slotsByDayId: {
        "day-1": [slot],
      },
      blocksByDayId: {
        "day-1": [
          _buildMealBlock(id: "lunch", dayId: "day-1", slotId: "slot-1"),
          _buildMealBlock(id: "dinner", dayId: "day-1", slotId: "slot-1"),
        ],
      },
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: 1000,
      buffetPriceCents: null,
    );

    await pumpView(tester, days: days, mealPriceCents: 1000);

    expect(find.text("2 + 2"), findsOneWidget);
  });

  testWidgets(
    "a meal price with no buffet price prints a real partial total with its coverage read-out",
    (tester) async {
      final day = buildDay(id: "day-1");
      final slot = buildSlot(
        id: "slot-1",
        dayId: "day-1",
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );

      final days = ocptBudgetLogisticsDaysOf(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [_buildMealBlock(id: "meal-1", dayId: "day-1", slotId: "slot-1")],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1200,
        buffetPriceCents: null,
      );

      await pumpView(tester, days: days, mealPriceCents: 1200);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetLogistics)));
      final totals = ocptBudgetLogisticsTotalsOf(days);
      expect(totals.cost.isComplete, isFalse);

      final coverageText = tr.budgetLogisticsCateringCoverageReadOut(
        ocptBudgetAmountLabel(totals.cost.amountCents, "EUR"),
        totals.cost.coveredLineCount,
        totals.cost.lineCount,
      );
      expect(find.text(coverageText), findsOneWidget);
    },
  );

  testWidgets("a defrayal reads its person, its nature and what it comes to", (tester) async {
    final day = buildDay(id: "day-1");
    final days = ocptBudgetLogisticsDaysOf(
      days: [day],
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
      allowances: [buildAllowance(id: "allowance-1", personId: "person-1", quantityMilli: 168000)],
      people: [buildPerson(id: "person-1", firstName: "Alex")],
      // The person's own group row shows their name whether expanded or not; the defrayal's own
      // nature, when and quantity sit in its own sub-row, which only draws once expanded.
      expandedNodeIds: const {"person-1"},
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetLogistics)));
    expect(find.text("Alex"), findsOneWidget);
    // 168 km at 0,529 €/km, the figure the published scale states — read on the person group row's
    // own `ADVANCED` cell and again on the defrayal sub-row's own.
    expect(find.text(ocptBudgetAmountLabel(8887, "EUR")), findsWidgets);
    expect(
      find.text("${tr.budgetAllowanceKindTravelLabel} · $ocptBudgetEmptyValue · ×168"),
      findsOneWidget,
    );
  });

  testWidgets("a defrayal naming nobody says so rather than reading blank", (tester) async {
    final days = ocptBudgetLogisticsDaysOf(
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
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetLogistics)));
    expect(find.text(tr.budgetLogisticsAllowanceNoPerson), findsOneWidget);
  });

  testWidgets("a defrayal with no date reads the em dash rather than inventing one", (
    tester,
  ) async {
    final days = ocptBudgetLogisticsDaysOf(
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
      allowances: [buildAllowance(id: "allowance-1", personId: "person-1")],
      people: [buildPerson(id: "person-1", firstName: "Alex")],
      expandedNodeIds: const {"person-1"},
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetLogistics)));
    expect(
      find.text("${tr.budgetAllowanceKindTravelLabel} · $ocptBudgetEmptyValue · ×1"),
      findsOneWidget,
    );
  });

  testWidgets("tapping a defrayal reports its id, and its menu asks rather than deleting", (
    tester,
  ) async {
    String? edited;
    String? deleted;
    final days = ocptBudgetLogisticsDaysOf(
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
      onAllowanceEditRequested: (id) => edited = id,
      onAllowanceDeletionRequested: (id) => deleted = id,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetLogistics)));
    await tester.tap(find.text(tr.budgetLogisticsAllowanceNoPerson));
    await tester.pumpAndSettle();
    expect(edited, "allowance-1");

    // The table sits at its own floor width inside a horizontal scroll, so the trailing menu is
    // scrolled to rather than merely present — which is the point of that floor.
    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetCommittedDeleteAction));
    await tester.pumpAndSettle();
    // The row asks; the mode is what opens `OcptConfirmDialog` over it.
    expect(deleted, "allowance-1");
  });
}
