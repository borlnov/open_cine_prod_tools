// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

void main() {
  group("one slot, one person", () {
    test("arrival and departure read off the slot's own bounds", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.personId, "person-1");
      expect(convocation.roleId, isNull);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.patStartMinute, 500);
      expect(convocation.patEndMinute, 590);
      expect(convocation.departureMinute, 600);
      expect(convocation.slotIds, ["slot-1"]);
    });
  });

  group("a person on two slots", () {
    test("arrival is the earliest, departure the latest, one PAT band spans both with a gap", () {
      const morning = OcptConvocationSlot(
        id: "slot-morning",
        startMinute: 480, // 08:00
        endMinute: 720, // 12:00
        shootingStartMinute: 510, // 08:30
        shootingEndMinute: 690, // 11:30
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const evening = OcptConvocationSlot(
        id: "slot-evening",
        startMinute: 1080, // 18:00
        endMinute: 1260, // 21:00
        shootingStartMinute: 1110, // 18:30
        shootingEndMinute: 1230, // 20:30
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [morning, evening]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 480);
      // The band spans from the morning's own first shot to the evening's own last, gaps between
      // the two slots included — it is not clipped to either slot alone.
      expect(convocation.patStartMinute, 510);
      expect(convocation.patEndMinute, 1230);
      expect(convocation.departureMinute, 1260);
      expect(convocation.slotIds, ["slot-morning", "slot-evening"]);
    });
  });

  group("a person on a preparation-only slot", () {
    test("has an arrival and a departure but no PAT band at all", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 540,
        shootingStartMinute: null,
        shootingEndMinute: null,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 540);
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
    });
  });

  group("a slot with no block at all", () {
    test("ends at its own start minute", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: null,
        shootingStartMinute: null,
        shootingEndMinute: null,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 480);
    });
  });

  group("an uncast role", () {
    test("gets its own row, named by the role rather than by nobody", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        personIds: {},
        uncastRoleIds: {"role-1"},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.personId, isNull);
      expect(convocation.roleId, "role-1");
      expect(convocation.arrivalMinute, 480);
    });
  });

  group("a night slot crossing midnight", () {
    test("minutes past 1440 are never taken modulo anything", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 1140, // 19:00
        endMinute: 1620, // 03:00 the next morning
        shootingStartMinute: 1140,
        shootingEndMinute: 1620,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 1140);
      expect(convocation.patStartMinute, 1140);
      expect(convocation.patEndMinute, 1620);
      expect(convocation.departureMinute, 1620);
    });
  });

  group("the result is sorted deterministically", () {
    test("by arrival minute, ties broken by personId ?? roleId", () {
      const early = OcptConvocationSlot(
        id: "slot-early",
        startMinute: 420,
        endMinute: 480,
        shootingStartMinute: null,
        shootingEndMinute: null,
        personIds: {"person-b"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const tiedOne = OcptConvocationSlot(
        id: "slot-tied-1",
        startMinute: 480,
        endMinute: 540,
        shootingStartMinute: null,
        shootingEndMinute: null,
        personIds: {"person-z"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const tiedTwo = OcptConvocationSlot(
        id: "slot-tied-2",
        startMinute: 480,
        endMinute: 540,
        shootingStartMinute: null,
        shootingEndMinute: null,
        personIds: {"person-a"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [tiedOne, early, tiedTwo]);

      expect(result.map((convocation) => convocation.personId), [
        "person-b",
        "person-a",
        "person-z",
      ]);
    });
  });

  group("an empty slots list", () {
    test("answers no convocation at all", () {
      expect(ocptComputeDayConvocations(slots: const []), isEmpty);
    });
  });

  group("a guest on a slot carrying shooting blocks", () {
    test("gets an arrival and a departure but never a PAT band", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {"guest-person-1"},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.isGuest, isTrue);
      expect(convocation.guestPersonId, "guest-person-1");
      expect(convocation.personId, isNull);
      expect(convocation.roleId, isNull);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 600);
      // The slot carries a shooting block, and still the guest reads no band at all: a guest does
      // not shoot, and a band would say they were waiting to.
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
    });
  });

  group("a guest linked to two slots of one day", () {
    test("reads one convocation spanning both", () {
      const morning = OcptConvocationSlot(
        id: "slot-morning",
        startMinute: 480,
        endMinute: 720,
        shootingStartMinute: 510,
        shootingEndMinute: 690,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {"guest-person-1"},
        guestFreeNames: {},
      );
      const evening = OcptConvocationSlot(
        id: "slot-evening",
        startMinute: 1080,
        endMinute: 1260,
        shootingStartMinute: 1110,
        shootingEndMinute: 1230,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {"guest-person-1"},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [morning, evening]);

      final convocation = result.single;
      expect(convocation.isGuest, isTrue);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 1260);
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
      expect(convocation.slotIds, ["slot-morning", "slot-evening"]);
    });
  });

  group("a person convoked as crew and attending the same day as a guest", () {
    test("reads as two separate convocations", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {"person-1"},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      expect(result, hasLength(2));
      final crewConvocation = result.firstWhere((convocation) => !convocation.isGuest);
      final guestConvocation = result.firstWhere((convocation) => convocation.isGuest);
      expect(crewConvocation.personId, "person-1");
      expect(crewConvocation.patStartMinute, 500);
      expect(guestConvocation.guestPersonId, "person-1");
      expect(guestConvocation.patStartMinute, isNull);
    });
  });

  group("a free-named guest", () {
    test("is grouped by its verbatim name, never normalised", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: null,
        shootingEndMinute: null,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {"Jean Dupont"},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.isGuest, isTrue);
      expect(convocation.guestFreeName, "Jean Dupont");
      expect(convocation.guestPersonId, isNull);
    });
  });
}
