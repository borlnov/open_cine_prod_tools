// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the day view's own scroll area.
Widget wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 640, height: 700, child: child)),
);

/// Builds a part with the few fields these tests read.
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

/// Builds a candidacy — somebody seen for a part — with the few fields these tests read.
OcptRoleCandidate buildCandidacy({
  required String id,
  required String roleId,
  required String firstName,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: OcptPerson(
    id: "person-$id",
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
    commuteKmMilli: null,
    mileageRateId: null,
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
    positions: const [],
    skills: const [],
    unavailabilities: const [],
  ),
  status: OcptRoleCandidateStatus.seen,
  auditionedOn: null,
  notes: "",
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock buildBlock({
  required String id,
  String slotId = "slot-1",
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
  String? shotId,
  String? sceneId,
  List<OcptShootingBlockCandidate> candidates = const [],
  int? anchorMinute,
  String label = "",
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: sceneId,
  candidates: candidates,
  label: label,
  durationMinutes: null,
  anchorMinute: anchorMinute,
  notes: "",
  crewNote: "",
);

/// A neutral `shotOf` resolving nothing, for tests that never place a shot block.
OcptShot? noShot(String shotId) => null;

/// A neutral `onBlockSelected` that ignores every click, for tests that don't assert on selection.
void ignoreString(String value) {}
