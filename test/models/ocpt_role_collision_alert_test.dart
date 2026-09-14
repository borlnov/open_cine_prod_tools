// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Builds a role, everything not passed left at a neutral value: these tests only read a role's
/// id, name and [isFromScreenplay].
OcptRole _buildRole({
  required String id,
  required String name,
  required bool isFromScreenplay,
  int number = 1,
}) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: isFromScreenplay,
  orphanedName: null,
  castingNotes: "",
  number: number,
  episodeIds: const [],
);

void main() {
  group("OcptRoleCollisionAlert.buildAll", () {
    test("a hand-added role sharing a name with a screenplay role is a collision", () {
      final screenplayRole = _buildRole(id: "role-1", name: "CLARA", isFromScreenplay: true);
      final handAddedRole = _buildRole(id: "role-2", name: "CLARA", isFromScreenplay: false);

      final alerts = OcptRoleCollisionAlert.buildAll([screenplayRole, handAddedRole]);

      expect(alerts, hasLength(1));
      expect(alerts.single.name, "CLARA");
      expect(alerts.single.screenplayRoleId, "role-1");
      expect(alerts.single.handAddedRoleId, "role-2");
    });

    test("the match is case- and whitespace-insensitive, like every other name comparison", () {
      final screenplayRole = _buildRole(id: "role-1", name: "CLARA", isFromScreenplay: true);
      final handAddedRole = _buildRole(id: "role-2", name: "  clara ", isFromScreenplay: false);

      final alerts = OcptRoleCollisionAlert.buildAll([screenplayRole, handAddedRole]);

      expect(alerts, hasLength(1));
      expect(alerts.single.name, "CLARA");
    });

    test("two screenplay roles sharing a name are not reported", () {
      final roles = [
        _buildRole(id: "role-1", name: "CLARA", isFromScreenplay: true),
        _buildRole(id: "role-2", name: "CLARA", isFromScreenplay: true),
      ];

      expect(OcptRoleCollisionAlert.buildAll(roles), isEmpty);
    });

    test("a hand-added role with no screenplay twin is not reported", () {
      final roles = [
        _buildRole(id: "role-1", name: "Extra crowd", isFromScreenplay: false),
        _buildRole(id: "role-2", name: "MARC", isFromScreenplay: true),
      ];

      expect(OcptRoleCollisionAlert.buildAll(roles), isEmpty);
    });

    test("two hand-added roles sharing a name are not reported", () {
      final roles = [
        _buildRole(id: "role-1", name: "Extra crowd", isFromScreenplay: false),
        _buildRole(id: "role-2", name: "Extra crowd", isFromScreenplay: false),
      ];

      expect(OcptRoleCollisionAlert.buildAll(roles), isEmpty);
    });

    test("several collisions come back sorted by name", () {
      final roles = [
        _buildRole(id: "role-marc-screenplay", name: "MARC", isFromScreenplay: true),
        _buildRole(id: "role-marc-hand", name: "MARC", isFromScreenplay: false),
        _buildRole(id: "role-clara-screenplay", name: "CLARA", isFromScreenplay: true),
        _buildRole(id: "role-clara-hand", name: "CLARA", isFromScreenplay: false),
      ];

      final alerts = OcptRoleCollisionAlert.buildAll(roles);

      expect(alerts.map((alert) => alert.name), ["CLARA", "MARC"]);
    });

    test("no roles at all means no collisions", () {
      expect(OcptRoleCollisionAlert.buildAll(const []), isEmpty);
    });
  });
}
