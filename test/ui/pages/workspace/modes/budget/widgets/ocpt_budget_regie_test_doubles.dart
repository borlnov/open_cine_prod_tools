// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide band
/// so the two columns draw side by side.
Widget wrap(Widget child, {Size size = const Size(1400, 700)}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: SizedBox(width: size.width, height: size.height, child: child),
  ),
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay buildDay({required String id, int dayNumber = 1, DateTime? date}) =>
    OcptShootingDay(
      id: id,
      date: date ?? DateTime(2026, 3),
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot buildSlot({
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
OcptShootingSlotCrewMember buildCrewMember({
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

/// Builds a person, the few fields these tests read, everything else neutral.
OcptPerson buildPerson({
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
OcptBudgetAllowance buildAllowance({
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
