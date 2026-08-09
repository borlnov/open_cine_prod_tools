// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_prefill.dart';

void main() {
  group("nothing declared", () {
    test("pre-fills nothing and promotes nothing", () {
      final result = ocptCrewPositionPrefillOf(declaredPositions: const [], heldOnSlot: const []);

      expect(result.prefill, isNull);
      expect(result.promotedPositions, isEmpty);
      expect(result.takenPositions, isEmpty);
    });
  });

  group("one declared position, nothing held", () {
    test("pre-fills that position", () {
      const sound = OcptCrewPositionRef(positionId: "sound", customLabel: "");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [sound],
        heldOnSlot: const [],
      );

      expect(result.prefill, sound);
      expect(result.promotedPositions, [sound]);
      expect(result.takenPositions, isEmpty);
    });
  });

  group("two declared positions, the first already held on that slot", () {
    test("pre-fills the second", () {
      const sound = OcptCrewPositionRef(positionId: "sound", customLabel: "");
      const boom = OcptCrewPositionRef(positionId: "boom", customLabel: "");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [sound, boom],
        heldOnSlot: const [sound],
      );

      expect(result.prefill, boom);
      expect(result.promotedPositions, [boom]);
      expect(result.takenPositions, {sound});
    });
  });

  group("everything declared already held", () {
    test("pre-fills nothing and promotes nothing", () {
      const sound = OcptCrewPositionRef(positionId: "sound", customLabel: "");
      const boom = OcptCrewPositionRef(positionId: "boom", customLabel: "");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [sound, boom],
        heldOnSlot: const [sound, boom],
      );

      expect(result.prefill, isNull);
      expect(result.promotedPositions, isEmpty);
      expect(result.takenPositions, {sound, boom});
    });
  });

  group("a free-label declared position", () {
    test("pre-fills the custom label", () {
      const rigger = OcptCrewPositionRef(positionId: "", customLabel: "Rigger");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [rigger],
        heldOnSlot: const [],
      );

      expect(result.prefill, rigger);
      expect(result.promotedPositions, [rigger]);
    });
  });

  group("duplicates in the declared list", () {
    test("the first occurrence wins, the position is promoted once", () {
      const sound = OcptCrewPositionRef(positionId: "sound", customLabel: "");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [sound, sound],
        heldOnSlot: const [],
      );

      expect(result.prefill, sound);
      expect(result.promotedPositions, [sound]);
    });
  });

  group("an empty ref among the declared positions", () {
    test("is never promoted and never pre-filled", () {
      const empty = OcptCrewPositionRef(positionId: "", customLabel: "");
      const sound = OcptCrewPositionRef(positionId: "sound", customLabel: "");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [empty, sound],
        heldOnSlot: const [],
      );

      expect(result.prefill, sound);
      expect(result.promotedPositions, [sound]);
    });
  });

  group("an empty ref in heldOnSlot", () {
    test("makes nothing taken", () {
      const sound = OcptCrewPositionRef(positionId: "sound", customLabel: "");
      const empty = OcptCrewPositionRef(positionId: "", customLabel: "");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [sound],
        heldOnSlot: const [empty],
      );

      expect(result.takenPositions, isEmpty);
      expect(result.prefill, sound);
    });
  });

  group("takenPositions holding a catalogue entry never declared", () {
    test("is still reported as taken", () {
      const boom = OcptCrewPositionRef(positionId: "boom", customLabel: "");

      final result = ocptCrewPositionPrefillOf(
        declaredPositions: const [],
        heldOnSlot: const [boom],
      );

      expect(result.takenPositions, {boom});
      expect(result.promotedPositions, isEmpty);
      expect(result.prefill, isNull);
    });
  });
}
