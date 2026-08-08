// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// What both schedule PDF exports hand [ocptScheduleBlockCaptionOf] as its own kind resolver —
/// recognisable placeholders rather than the real localized labels, which live in the UI layer.
String _blockKindLabelOf(OcptShootingBlockKind kind) => switch (kind) {
  OcptShootingBlockKind.shot => "Shot",
  OcptShootingBlockKind.preparation => "Preparation",
  OcptShootingBlockKind.hairMakeUp => "HMC",
  OcptShootingBlockKind.meal => "Meal break",
  OcptShootingBlockKind.pause => "Break",
  OcptShootingBlockKind.travel => "Travel",
  OcptShootingBlockKind.wrap => "Wrap",
  OcptShootingBlockKind.hold => "Reserved",
};

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({List<OcptShootingSlotCastMember> cast = const []}) => OcptShootingSlot(
  id: "slot-1",
  shootingDayId: "day-1",
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: cast,
  guests: const [],
);

/// Builds a cast member linking [roleId] to the fixture's own slot.
OcptShootingSlotCastMember _buildCastMember(String roleId) =>
    OcptShootingSlotCastMember(id: "cast-$roleId", slotId: "slot-1", roleId: roleId, notes: "");

/// Builds a block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required OcptShootingBlockKind kind,
  String label = "",
  String? sceneId,
}) => OcptShootingDayBlock(
  id: "block-1",
  shootingDayId: "day-1",
  slotId: "slot-1",
  kind: kind,
  shotId: null,
  sceneId: sceneId,
  label: label,
  durationMinutes: 30,
  anchorMinute: null,
  notes: "",
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required int number}) => OcptRole(
  id: id,
  screenplayId: "screenplay-1",
  name: "Role $number",
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: number,
);

void main() {
  final roleById = {
    "role-a": _buildRole(id: "role-a", number: 5),
    "role-b": _buildRole(id: "role-b", number: 3),
    "role-c": _buildRole(id: "role-c", number: 8),
  };

  group("ocptScheduleSlotRoleNumbersOf", () {
    test("reads the slot's own cast, sorted ascending rather than in link order", () {
      final slot = _buildSlot(
        cast: [_buildCastMember("role-a"), _buildCastMember("role-c"), _buildCastMember("role-b")],
      );

      expect(ocptScheduleSlotRoleNumbersOf(slot: slot, roleById: roleById), [3, 5, 8]);
    });

    test("a slot convoking nobody answers with no number at all", () {
      expect(ocptScheduleSlotRoleNumbersOf(slot: _buildSlot(), roleById: roleById), isEmpty);
    });

    test("a cast row naming a role the project no longer holds is skipped, not printed as a gap", () {
      final slot = _buildSlot(cast: [_buildCastMember("role-a"), _buildCastMember("role-gone")]);

      expect(ocptScheduleSlotRoleNumbersOf(slot: slot, roleById: roleById), [5]);
    });
  });

  group("ocptScheduleBlockRoleNumbersOf", () {
    test("an HMC block answers with the numbers of the roles its slot convokes", () {
      final numbers = ocptScheduleBlockRoleNumbersOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp),
        slot: _buildSlot(cast: [_buildCastMember("role-a"), _buildCastMember("role-b")]),
        roleById: roleById,
      );

      expect(numbers, [3, 5]);
    });

    test("an HMC block on a slot convoking nobody answers with no number at all", () {
      final numbers = ocptScheduleBlockRoleNumbersOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp),
        slot: _buildSlot(),
        roleById: roleById,
      );

      expect(numbers, isEmpty);
    });

    test("every other kind carries none, however much cast its slot convokes", () {
      final slot = _buildSlot(cast: [_buildCastMember("role-a"), _buildCastMember("role-b")]);

      for (final kind in OcptShootingBlockKind.values) {
        if (kind == OcptShootingBlockKind.hairMakeUp) {
          continue;
        }
        expect(
          ocptScheduleBlockRoleNumbersOf(block: _buildBlock(kind: kind), slot: slot, roleById: roleById),
          isEmpty,
          reason: "a $kind block must not carry its slot's role numbers",
        );
      }
    });
  });

  group("ocptScheduleBlockRoleNumbersLine", () {
    test("names the numbers behind the calling document's own label", () {
      expect(
        ocptScheduleBlockRoleNumbersLine(roleNumbers: const [3, 5], rolesLabel: "CAST"),
        "CAST : 3, 5",
      );
    });

    test("a band expecting nobody prints no line at all", () {
      expect(ocptScheduleBlockRoleNumbersLine(roleNumbers: const [], rolesLabel: "CAST"), isNull);
    });
  });

  group("ocptScheduleBlockCaptionOf", () {
    test("an HMC block's own caption carries no role number of its own", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp),
        headingBySceneId: const {},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "HMC");
    });

    test("an HMC block's own free text is printed as it stands", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp, label: "HMC dressing room 2"),
        headingBySceneId: const {},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "HMC dressing room 2");
    });

    test("every kind with no caption of its own falls back to its kind label", () {
      for (final kind in OcptShootingBlockKind.values) {
        expect(
          ocptScheduleBlockCaptionOf(
            block: _buildBlock(kind: kind),
            headingBySceneId: const {},
            blockKindLabelOf: _blockKindLabelOf,
          ),
          _blockKindLabelOf(kind),
        );
      }
    });

    test("a hold block names its own sequence's heading over the kind label", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hold, sceneId: "scene-1"),
        headingBySceneId: const {"scene-1": "INT. HOUSE - DAY"},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "INT. HOUSE - DAY");
    });

    test("a block's own free text wins over both its sequence heading and its kind label", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hold, sceneId: "scene-1", label: "Reserved for the storm"),
        headingBySceneId: const {"scene-1": "INT. HOUSE - DAY"},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "Reserved for the storm");
    });
  });
}
