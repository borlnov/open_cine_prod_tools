// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_regie.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide band
/// so the two columns draw side by side.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1400, height: 700, child: child)),
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, int dayNumber = 1, DateTime? date}) => OcptShootingDay(
  id: id,
  date: date ?? DateTime(2026, 3),
  dayNumber: dayNumber,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
  required String dayId,
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
  List<OcptShootingSlotGuest> guests = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: dayId,
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: crew,
  cast: cast,
  guests: guests,
);

/// Builds a crew assignment, the few fields these tests read.
OcptShootingSlotCrewMember _buildCrewMember({
  required String id,
  required String slotId,
  required String personId,
}) => OcptShootingSlotCrewMember(
  id: id,
  slotId: slotId,
  personId: personId,
  positionId: "",
  customLabel: "",
  notes: "",
);

/// Builds a cast convocation naming [roleId], the few fields these tests read.
OcptShootingSlotCastMember _buildCastMember({
  required String id,
  required String slotId,
  required String roleId,
}) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

/// Builds a guest attendance naming [personId], the few fields these tests read.
OcptShootingSlotGuest _buildGuest({required String id, required String slotId, required String personId}) =>
    OcptShootingSlotGuest(id: id, slotId: slotId, personId: personId, freeName: "", reason: "", notes: "");

/// Builds a meal block on [slotId], the few fields these tests read.
OcptShootingDayBlock _buildMealBlock({required String id, required String dayId, required String slotId}) =>
    OcptShootingDayBlock(
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

/// Builds a person, the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({
  required String id,
  String firstName = "",
  int? commuteKmMilli,
  String? mileageRateId,
}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: "",
  email: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: 0,
  birthDate: null,
  minorNotes: "",
  maxDailyPresenceMinutes: null,
  isTransportAutonomous: null,
  accommodationNotes: "",
  travelNotes: "",
  dietaryNotes: "",
  allergies: "",
  measurementHeight: "",
  measurementChest: "",
  measurementWaist: "",
  measurementHips: "",
  sizeTop: "",
  sizeBottom: "",
  sizeShoes: "",
  hmcNotes: "",
  imageRightsStatus: OcptImageRightsStatus.notApplicable,
  imageRightsDate: null,
  imageRightsAssetId: null,
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
  notes: "",
  commuteKmMilli: commuteKmMilli,
  mileageRateId: mileageRateId,
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// A minimal defrayal, everything but what each test actually varies neutral.
OcptBudgetAllowance _buildAllowance({
  required String id,
  String? personId,
  OcptBudgetAllowanceKind kind = OcptBudgetAllowanceKind.travel,
  String label = "",
  DateTime? date,
  DateTime? endDate,
  int quantityMilli = 1000,
  int unitAmountMilliCents = 52900,
}) => OcptBudgetAllowance(
  id: id,
  personId: personId,
  kind: kind,
  label: label,
  date: date,
  endDate: endDate,
  quantityMilli: quantityMilli,
  unitAmountMilliCents: unitAmountMilliCents,
  notes: "",
  sortKey: "a0",
);

/// A minimal poste holding no line, offered by the provisioning band's own picker.
OcptBudgetPoste _buildPoste({required String id}) =>
    OcptBudgetPoste(id: id, code: "6", label: "Régie", simpleLabel: null, sortKey: "a0", lines: const []);

void main() {
  /// Pumps [OcptBudgetRegie] with every callback a no-op unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<OcptBudgetRegieDay> days,
    List<OcptBudgetAllowance> allowances = const [],
    List<OcptBudgetPoste> postes = const [],
    String? provisionPosteId,
    int provisionedTotalCents = 0,
    Map<String, String> decorNameByDayId = const {},
    int? mealPriceCents,
    int? buffetPriceCents,
    List<OcptRole> roles = const [],
    List<OcptPerson> people = const [],
    bool isReadOnly = false,
    ValueChanged<String>? onPersonOpenRequested,
    VoidCallback? onScheduleOpenRequested,
    VoidCallback? onProjectSettingsRequested,
    VoidCallback? onAllowanceCreationRequested,
    ValueChanged<String>? onAllowanceEditRequested,
    ValueChanged<String>? onAllowanceDeletionRequested,
    ValueChanged<String>? onProvisionPosteSelected,
    VoidCallback? onProvisionRequested,
    String? provisionNote,
  }) async {
    // The default test surface is narrower than `_ocptRegieWrapWidth`, which would silently
    // switch every test onto the stacked layout instead of the side-by-side one this suite means
    // to exercise — widened here so the wrapping `SizedBox` below isn't itself clamped down.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetRegie(
          days: days,
          cateringTotals: ocptBudgetRegieTotalsOf(days),
          decorNameByDayId: decorNameByDayId,
          mealPriceCents: mealPriceCents,
          buffetPriceCents: buffetPriceCents,
          allowances: allowances,
          postes: postes,
          provisionPosteId: provisionPosteId,
          provisionedTotalCents: provisionedTotalCents,
          roles: roles,
          people: people,
          currencyCode: "EUR",
          isReadOnly: isReadOnly,
          onAllowanceCreationRequested: onAllowanceCreationRequested ?? () {},
          onAllowanceEditRequested: onAllowanceEditRequested ?? (_) {},
          onAllowanceDeletionRequested: onAllowanceDeletionRequested ?? (_) {},
          onProvisionPosteSelected: onProvisionPosteSelected ?? (_) {},
          onProvisionRequested: onProvisionRequested ?? () {},
          provisionNote: provisionNote,
          onScheduleOpenRequested: onScheduleOpenRequested ?? () {},
          onProjectSettingsRequested: onProjectSettingsRequested ?? () {},
          onPersonOpenRequested: onPersonOpenRequested ?? (_) {},
        ),
      ),
    );
  }

  testWidgets("a project with no shooting day at all shows the shared empty state", (tester) async {
    await pumpView(tester, days: const []);

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets(
    "a day's buffet count is rendered from its slots, a person convoked to three slots counted once",
    (tester) async {
      final day = _buildDay(id: "day-1");
      final slots = [
        _buildSlot(
          id: "slot-1",
          dayId: "day-1",
          crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
        ),
        _buildSlot(
          id: "slot-2",
          dayId: "day-1",
          crew: [_buildCrewMember(id: "crew-2", slotId: "slot-2", personId: "person-1")],
        ),
        _buildSlot(
          id: "slot-3",
          dayId: "day-1",
          crew: [_buildCrewMember(id: "crew-3", slotId: "slot-3", personId: "person-1")],
        ),
      ];

      final days = ocptBudgetRegieDaysOf(
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
    final day = _buildDay(id: "day-1");
    final slot = _buildSlot(
      id: "slot-1",
      dayId: "day-1",
      cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-extra")],
    );

    final days = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slot]},
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
    final day = _buildDay(id: "day-1");
    final slotWithoutGuest = _buildSlot(id: "slot-1", dayId: "day-1");
    final slotWithGuest = _buildSlot(
      id: "slot-2",
      dayId: "day-1",
      guests: [_buildGuest(id: "guest-1", slotId: "slot-2", personId: "person-visitor")],
    );

    final withoutGuest = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slotWithoutGuest]},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );
    final withGuest = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slotWithGuest]},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    expect(withGuest.single.buffetCount, withoutGuest.single.buffetCount);
    expect(withGuest.single.buffetCount, 0);
  });

  testWidgets("a day with no meal block reads a dash in the Meals column, not a zero", (tester) async {
    final day = _buildDay(id: "day-1");
    final slot = _buildSlot(
      id: "slot-1",
      dayId: "day-1",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
    );

    final days = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slot]},
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
    final day = _buildDay(id: "day-1");
    final slot = _buildSlot(
      id: "slot-1",
      dayId: "day-1",
      crew: [
        _buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1"),
        _buildCrewMember(id: "crew-2", slotId: "slot-1", personId: "person-2"),
      ],
    );

    final days = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slot]},
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
      final day = _buildDay(id: "day-1");
      final slot = _buildSlot(
        id: "slot-1",
        dayId: "day-1",
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [_buildMealBlock(id: "meal-1", dayId: "day-1", slotId: "slot-1")],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1200,
        buffetPriceCents: null,
      );

      await pumpView(tester, days: days, mealPriceCents: 1200);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
      final totals = ocptBudgetRegieTotalsOf(days);
      expect(totals.cost.isComplete, isFalse);

      final coverageText = tr.budgetRegieCateringCoverageReadOut(
        ocptBudgetAmountLabel(totals.cost.amountCents, "EUR"),
        totals.cost.coveredLineCount,
        totals.cost.lineCount,
      );
      expect(find.text(coverageText), findsOneWidget);
    },
  );

  testWidgets("a defrayal reads its person, its nature and what it comes to", (tester) async {
    final day = _buildDay(id: "day-1");
    final days = ocptBudgetRegieDaysOf(
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
      allowances: [
        _buildAllowance(id: "allowance-1", personId: "person-1", quantityMilli: 168000),
      ],
      people: [_buildPerson(id: "person-1", firstName: "Alex")],
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    expect(find.text("Alex"), findsOneWidget);
    expect(find.text(tr.budgetAllowanceKindTravelLabel), findsWidgets);
    // 168 km at 0,529 €/km, the figure the published scale states.
    expect(find.text(ocptBudgetAmountLabel(8887, "EUR")), findsWidgets);
  });

  testWidgets("a defrayal naming nobody says so rather than reading blank", (tester) async {
    final days = ocptBudgetRegieDaysOf(
      days: [_buildDay(id: "day-1")],
      slotsByDayId: const {},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    await pumpView(tester, days: days, allowances: [_buildAllowance(id: "allowance-1")]);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    expect(find.text(tr.budgetRegieAllowanceNoPerson), findsOneWidget);
  });

  testWidgets("a defrayal with no date reads the em dash rather than inventing one", (tester) async {
    final days = ocptBudgetRegieDaysOf(
      days: [_buildDay(id: "day-1")],
      slotsByDayId: const {},
      blocksByDayId: const {},
      roleKindById: const {},
      personIdByRoleId: const {},
      mealPriceCents: null,
      buffetPriceCents: null,
    );

    await pumpView(tester, days: days, allowances: [_buildAllowance(id: "allowance-1")]);

    expect(find.text(ocptBudgetEmptyValue), findsWidgets);
  });

  testWidgets("tapping a defrayal reports its id, and its menu asks rather than deleting", (
    tester,
  ) async {
    String? edited;
    String? deleted;
    final days = ocptBudgetRegieDaysOf(
      days: [_buildDay(id: "day-1")],
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
      allowances: [_buildAllowance(id: "allowance-1")],
      onAllowanceEditRequested: (id) => edited = id,
      onAllowanceDeletionRequested: (id) => deleted = id,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    await tester.tap(find.text(tr.budgetRegieAllowanceNoPerson));
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

  testWidgets("the provisioning band reads the gap between what is computed and what is quoted", (
    tester,
  ) async {
    final days = ocptBudgetRegieDaysOf(
      days: [_buildDay(id: "day-1")],
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
      allowances: [_buildAllowance(id: "allowance-1", quantityMilli: 168000)],
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
      days: [_buildDay(id: "day-1")],
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
      days: [_buildDay(id: "day-1")],
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
      days: [_buildDay(id: "day-1")],
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
      allowances: [_buildAllowance(id: "allowance-1")],
      postes: [_buildPoste(id: "poste-1")],
      provisionPosteId: "poste-1",
      isReadOnly: true,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetRegie)));
    // Withheld, never disabled: the controls are not on screen at all.
    expect(find.text(tr.budgetRegieAllowanceCreationAction), findsNothing);
    expect(find.text(tr.budgetRegieProvisionAction), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    // The reading itself is untouched — a version is still read.
    expect(find.text(tr.budgetRegieAllowanceNoPerson), findsOneWidget);
  });

  testWidgets("a project with defrayals but no shooting day keeps its layout", (tester) async {
    // The empty state is for a project holding neither, now that this view has a `+` action of its
    // own to keep a heading band drawn for.
    await pumpView(tester, days: const [], allowances: [_buildAllowance(id: "allowance-1")]);

    expect(find.byType(OcptWorkspaceEmptyMode), findsNothing);
  });
}
