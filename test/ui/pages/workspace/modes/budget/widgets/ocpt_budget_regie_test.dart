// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
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

void main() {
  /// Pumps [OcptBudgetRegie] with every callback a no-op unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<OcptBudgetRegieDay> days,
    List<OcptBudgetTravelRow> travelRows = const [],
    Map<String, String> decorNameByDayId = const {},
    int? mealPriceCents,
    int? snackPriceCents,
    List<OcptRole> roles = const [],
    List<OcptPerson> people = const [],
    ValueChanged<String>? onPersonOpenRequested,
    VoidCallback? onScheduleOpenRequested,
    VoidCallback? onProjectSettingsRequested,
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
          snackPriceCents: snackPriceCents,
          travelRows: travelRows,
          travelTotals: ocptBudgetTravelTotalsOf(travelRows),
          roles: roles,
          people: people,
          currencyCode: "EUR",
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
    "a day's counts are rendered from its slots, a person convoked to three slots counted once",
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
        roleKindById: const {},
        mealPriceCents: null,
        snackPriceCents: null,
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
      roleKindById: const {"role-extra": OcptRoleKind.extra},
      mealPriceCents: null,
      snackPriceCents: null,
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
      roleKindById: const {},
      mealPriceCents: null,
      snackPriceCents: null,
    );
    final withGuest = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slotWithGuest]},
      roleKindById: const {},
      mealPriceCents: null,
      snackPriceCents: null,
    );

    expect(withGuest.single.headCount, withoutGuest.single.headCount);
    expect(withGuest.single.headCount, 0);
  });

  testWidgets(
    "a meal price with no snack price prints a real partial total with its coverage read-out",
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
        roleKindById: const {},
        mealPriceCents: 1200,
        snackPriceCents: null,
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

  testWidgets("a traveller with no rate reads the em dash while their trip count still shows", (
    tester,
  ) async {
    final day = _buildDay(id: "day-1");
    final slot = _buildSlot(
      id: "slot-1",
      dayId: "day-1",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
    );

    // The catering days list is never empty in real use whenever a travel row is present — both
    // are read off the same schedule days — so this day is carried too, keeping the view off its
    // own empty state.
    final days = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slot]},
      roleKindById: const {},
      mealPriceCents: null,
      snackPriceCents: null,
    );
    final travelRows = ocptBudgetTravelRowsOf(
      days: [day],
      slotsByDayId: {"day-1": [slot]},
      personIdByRoleId: const {},
      commuteKmMilliByPersonId: const {"person-1": 8000},
      mileageRateIdByPersonId: const {"person-1": null},
      ratePerKmMilliCentsByRateId: const {},
    );

    expect(travelRows.single.totalKmMilli, isNotNull);
    expect(travelRows.single.amountCents, isNull);

    await pumpView(
      tester,
      days: days,
      travelRows: travelRows,
      people: [_buildPerson(id: "person-1", firstName: "Alex")],
    );

    expect(find.text(ocptBudgetEmptyValue), findsWidgets);
    // Not `findsOneWidget`: the same numeral legitimately also reads the day's own crew count.
    expect(find.text("${travelRows.single.returnTripCount}"), findsWidgets);
  });

  testWidgets("tapping a traveller's row reports that person's id", (tester) async {
    final day = _buildDay(id: "day-1");
    final slot = _buildSlot(
      id: "slot-1",
      dayId: "day-1",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
    );

    final days = ocptBudgetRegieDaysOf(
      days: [day],
      slotsByDayId: {"day-1": [slot]},
      roleKindById: const {},
      mealPriceCents: null,
      snackPriceCents: null,
    );
    final travelRows = ocptBudgetTravelRowsOf(
      days: [day],
      slotsByDayId: {"day-1": [slot]},
      personIdByRoleId: const {},
      commuteKmMilliByPersonId: const {},
      mileageRateIdByPersonId: const {},
      ratePerKmMilliCentsByRateId: const {},
    );

    String? reportedPersonId;
    await pumpView(
      tester,
      days: days,
      travelRows: travelRows,
      people: [_buildPerson(id: "person-1", firstName: "Alex")],
      onPersonOpenRequested: (personId) => reportedPersonId = personId,
    );

    await tester.tap(find.text("Alex"));

    expect(reportedPersonId, "person-1");
  });
}
