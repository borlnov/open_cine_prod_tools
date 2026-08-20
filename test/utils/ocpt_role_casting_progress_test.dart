// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_role_casting_progress.dart';

/// Builds a minimal [OcptRole], cast in [personId] or not.
OcptRole _role({required String id, String? personId}) => OcptRole(
  id: id,
  name: "",
  personId: personId,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// A minimal [OcptPerson], enough to join a candidacy to.
OcptPerson _person(String id) => OcptPerson(
  id: id,
  firstName: "",
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
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a minimal [OcptRoleCandidate], seen for role [roleId].
OcptRoleCandidate _candidate({
  required String id,
  required String roleId,
  OcptRoleCandidateStatus status = OcptRoleCandidateStatus.seen,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: _person("person-$id"),
  status: status,
  auditionedOn: null,
  notes: "",
);

void main() {
  group("OcptRoleCastingProgress.of", () {
    test("a cast role is `cast`, whatever candidates it also carries", () {
      final progress = OcptRoleCastingProgress.of(
        role: _role(id: "r1", personId: "p1"),
        candidates: [_candidate(id: "c1", roleId: "r1")],
      );

      expect(progress.stage, OcptRoleCastingStage.cast);
      expect(progress.candidateCount, 1);
    });

    test("a cast role with no candidate left is still `cast`", () {
      final progress = OcptRoleCastingProgress.of(
        role: _role(id: "r1", personId: "p1"),
        candidates: const [],
      );

      expect(progress.stage, OcptRoleCastingStage.cast);
      expect(progress.candidateCount, 0);
    });

    test("an uncast role with at least one live candidate is `inProgress`", () {
      final progress = OcptRoleCastingProgress.of(
        role: _role(id: "r1"),
        candidates: [
          _candidate(id: "c1", roleId: "r1"),
          _candidate(id: "c2", roleId: "r1", status: OcptRoleCandidateStatus.declined),
        ],
      );

      expect(progress.stage, OcptRoleCastingStage.inProgress);
      expect(progress.candidateCount, 2);
    });

    test("an uncast role with no candidate is `notStarted`", () {
      final progress = OcptRoleCastingProgress.of(role: _role(id: "r1"), candidates: const []);

      expect(progress.stage, OcptRoleCastingStage.notStarted);
      expect(progress.candidateCount, 0);
    });
  });

  group("ocptCastRoleCount", () {
    test("counts only the roles carrying a personId", () {
      final count = ocptCastRoleCount([
        _role(id: "r1", personId: "p1"),
        _role(id: "r2"),
        _role(id: "r3", personId: "p3"),
      ]);

      expect(count, 2);
    });

    test("is zero for an empty cast", () {
      expect(ocptCastRoleCount(const []), 0);
    });
  });
}
