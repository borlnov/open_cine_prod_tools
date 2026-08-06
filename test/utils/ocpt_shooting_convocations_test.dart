// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

void main() {
  group("crew — call and wrap read off the slot's own band", () {
    test("callMinute is the band start minus the lead, wrapMinute is the band end", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 480,
        blocks: const [
          OcptConvocationBlock(startMinute: 480, endMinute: 540, roleIds: {}),
          OcptConvocationBlock(startMinute: 540, endMinute: 600, roleIds: {}),
        ],
        crew: const [OcptCrewConvocationInput(id: "crew-1", leadMinutes: 30)],
        cast: const [],
      );

      final crew = result.crew.single;
      expect(crew.callMinute, 450); // 480 - 30
      expect(crew.wrapMinute, 600);
      expect(crew.leadMinutes, 30);
    });

    test("a night slot crossing midnight is never taken modulo anything", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 1140, // 19:00
        blocks: const [
          OcptConvocationBlock(startMinute: 1140, endMinute: 1440, roleIds: {"role-1"}),
          OcptConvocationBlock(startMinute: 1440, endMinute: 1620, roleIds: {"role-1"}), // -> 03:00
        ],
        crew: const [OcptCrewConvocationInput(id: "crew-1", leadMinutes: 45)],
        cast: const [OcptCastConvocationInput(id: "cast-1", roleId: "role-1", leadMinutes: 60)],
      );

      expect(result.crew.single.callMinute, 1095); // 18:15, still expressed past no wrap point
      expect(result.crew.single.wrapMinute, 1620); // 03:00 the following morning
      expect(result.cast.single.patStartMinute, 1140);
      expect(result.cast.single.patEndMinute, 1620);
      expect(result.cast.single.arrivalMinute, 1080); // 18:00
    });
  });

  group("cast — PAT band from the blocks naming the role", () {
    test("patStart/patEnd span only the blocks naming that role", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 480,
        blocks: const [
          OcptConvocationBlock(startMinute: 480, endMinute: 500, roleIds: {}), // preparation
          OcptConvocationBlock(startMinute: 500, endMinute: 560, roleIds: {"role-1"}),
          OcptConvocationBlock(startMinute: 560, endMinute: 600, roleIds: {}),
        ],
        crew: const [],
        cast: const [OcptCastConvocationInput(id: "cast-1", roleId: "role-1", leadMinutes: 20)],
      );

      final cast = result.cast.single;
      expect(cast.patStartMinute, 500);
      expect(cast.patEndMinute, 560);
      expect(cast.arrivalMinute, 480);
    });

    test("a role convoked but never used by any block keeps the slot's own bounds", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 480,
        blocks: const [
          OcptConvocationBlock(startMinute: 480, endMinute: 540, roleIds: {"role-other"}),
          OcptConvocationBlock(startMinute: 540, endMinute: 600, roleIds: {}),
        ],
        crew: const [],
        cast: const [OcptCastConvocationInput(id: "cast-1", roleId: "role-never-named", leadMinutes: 10)],
      );

      final cast = result.cast.single;
      // Someone convoked and not used is still convoked, over the slot's own whole band.
      expect(cast.patStartMinute, 480);
      expect(cast.patEndMinute, 600);
      expect(cast.arrivalMinute, 470);
    });
  });

  group("leads — the row's own figure wins over its group's", () {
    test("a row with its own lead ignores the group's figure", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 480,
        blocks: const [OcptConvocationBlock(startMinute: 480, endMinute: 540, roleIds: {})],
        crew: const [OcptCrewConvocationInput(id: "crew-1", leadMinutes: 15, groupLeadMinutes: 90)],
        cast: const [],
      );

      expect(result.crew.single.leadMinutes, 15);
      expect(result.crew.single.callMinute, 465); // 480 - 15, not 480 - 90
    });

    test("a row with no lead of its own falls back to its group's", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 480,
        blocks: const [OcptConvocationBlock(startMinute: 480, endMinute: 540, roleIds: {"role-1"})],
        crew: const [],
        cast: const [OcptCastConvocationInput(id: "cast-1", roleId: "role-1", groupLeadMinutes: 45)],
      );

      expect(result.cast.single.leadMinutes, 45);
      expect(result.cast.single.arrivalMinute, 435); // 480 - 45
    });

    test("a row with neither its own lead nor a group resolves to zero", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 480,
        blocks: const [OcptConvocationBlock(startMinute: 480, endMinute: 540, roleIds: {})],
        crew: const [OcptCrewConvocationInput(id: "crew-1")],
        cast: const [],
      );

      expect(result.crew.single.leadMinutes, 0);
      expect(result.crew.single.callMinute, 480); // arriving ready, right on the band start
    });

    test("a negative resolved lead is refused rather than convoking someone late", () {
      expect(
        () => ocptComputeSlotConvocations(
          slotStartMinute: 480,
          blocks: const [OcptConvocationBlock(startMinute: 480, endMinute: 540, roleIds: {})],
          crew: const [OcptCrewConvocationInput(id: "crew-1", leadMinutes: -10)],
          cast: const [],
        ),
        throwsArgumentError,
      );
    });

    test("a negative group lead is refused too, when the row carries no override", () {
      expect(
        () => ocptComputeSlotConvocations(
          slotStartMinute: 480,
          blocks: const [OcptConvocationBlock(startMinute: 480, endMinute: 540, roleIds: {"role-1"})],
          crew: const [],
          cast: const [OcptCastConvocationInput(id: "cast-1", roleId: "role-1", groupLeadMinutes: -5)],
        ),
        throwsArgumentError,
      );
    });
  });

  group("a slot with no block at all", () {
    test("wrapMinute and patEndMinute are null, the rest reads off the slot's own start", () {
      final result = ocptComputeSlotConvocations(
        slotStartMinute: 480,
        blocks: const [],
        crew: const [OcptCrewConvocationInput(id: "crew-1", leadMinutes: 15)],
        cast: const [OcptCastConvocationInput(id: "cast-1", roleId: "role-1", leadMinutes: 20)],
      );

      final crew = result.crew.single;
      expect(crew.callMinute, 465); // 480 - 15
      expect(crew.wrapMinute, isNull);

      final cast = result.cast.single;
      expect(cast.patStartMinute, 480);
      expect(cast.patEndMinute, isNull);
      expect(cast.arrivalMinute, 460); // 480 - 20
    });
  });
}
