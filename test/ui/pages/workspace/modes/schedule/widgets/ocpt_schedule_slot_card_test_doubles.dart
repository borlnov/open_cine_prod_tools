// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// The navigator [wrapInApp] mounts, so [RecordingRouterManager.pop] can close a dialog opened
/// through `showDialog` (the crew position picker) exactly as the real `GoRouter.pop` would —
/// both push onto the very same root `Navigator`. Mirrors `schedule_mode_test.dart`'s own
/// instance of the same pattern.
final navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [navigatorKey]'s own navigator, so a dialog opened through
/// `showDialog` genuinely closes: this card resolves its router manager from `globalGetIt()`,
/// with no real GoRouter for `pop` to delegate to.
class RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, [navigatorKey] so
/// [RecordingRouterManager.pop] can close a dialog opened through `showDialog`, inside a sized
/// box standing in for the day view's own scroll area.
Widget wrapInApp(Widget child) => MaterialApp(
  navigatorKey: navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 640, height: 700, child: child)),
);

/// Builds a slot with the few fields these tests read, everything else neutral — anchored by its
/// start at 08:00 unless a test says otherwise.
OcptShootingSlot buildSlot({
  String id = "slot-1",
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
  List<OcptShootingSlotGuest> guests = const [],
  OcptShootingSlotAnchorEdge anchorEdge = OcptShootingSlotAnchorEdge.start,
  int? anchorMinute = 480,
  String? anchorSlotId,
}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: "Matin",
  locationId: null,
  setId: null,
  anchorEdge: anchorEdge,
  anchorMinute: anchorMinute,
  anchorSlotId: anchorSlotId,
  notes: "",
  crew: crew,
  cast: cast,
  guests: guests,
);

/// Builds a person with the few fields these tests read, everything else neutral.
OcptPerson buildPerson({
  required String id,
  required String firstName,
  List<OcptPersonPosition> positions = const [],
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
  commuteKmMilli: null,
  mileageRateId: null,
  positions: positions,
  skills: const [],
  unavailabilities: const [],
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole buildRole({required String id, required String name}) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock buildBlock({
  required String id,
  required String slotId,
  String label = "",
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: null,
  sceneId: null,
  candidates: const [],
  label: label,
  durationMinutes: null,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

/// A neutral `shotOf` resolving nothing, for tests that never place a shot block.
OcptShot? noShot(String shotId) => null;
