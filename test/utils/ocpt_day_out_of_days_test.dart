// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_out_of_days.dart';

/// Builds the day `day-<number>`, convoking [roleIds].
OcptDayOutOfDaysDay _day(int number, Set<String> roleIds) =>
    OcptDayOutOfDaysDay(id: "day-$number", convokedRoleIds: roleIds);

void main() {
  group("a role's own span", () {
    test("a role convoked on the first and the last of three days holds the middle one", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {"role-1"}),
          _day(2, {}),
          _day(3, {"role-1"}),
        ],
        roleIds: const ["role-1"],
      );

      final row = table.rows.single;
      expect(row.codeOf("day-1"), OcptDayOutOfDaysCode.startWork);
      expect(row.codeOf("day-2"), OcptDayOutOfDaysCode.hold);
      expect(row.codeOf("day-3"), OcptDayOutOfDaysCode.workFinish);
      expect(row.workedDayCount, 2);
      expect(row.heldDayCount, 1);
    });

    test("a day before the first and after the last carries no code at all", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {}),
          _day(2, {"role-1"}),
          _day(3, {"role-1"}),
          _day(4, {}),
        ],
        roleIds: const ["role-1"],
      );

      final row = table.rows.single;
      expect(row.codeOf("day-1"), isNull);
      expect(row.codeOf("day-2"), OcptDayOutOfDaysCode.startWork);
      expect(row.codeOf("day-3"), OcptDayOutOfDaysCode.workFinish);
      expect(row.codeOf("day-4"), isNull);
      expect(row.codeByDayId.keys, ["day-2", "day-3"]);
    });

    test("a middle worked day reads as plain work", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {"role-1"}),
          _day(2, {"role-1"}),
          _day(3, {"role-1"}),
        ],
        roleIds: const ["role-1"],
      );

      final row = table.rows.single;
      expect(row.codeOf("day-2"), OcptDayOutOfDaysCode.work);
      expect(row.workedDayCount, 3);
      expect(row.heldDayCount, 0);
    });

    test("several holds inside one span are all counted", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {"role-1"}),
          _day(2, {}),
          _day(3, {}),
          _day(4, {"role-1"}),
          _day(5, {}),
        ],
        roleIds: const ["role-1"],
      );

      final row = table.rows.single;
      expect(row.codeOf("day-2"), OcptDayOutOfDaysCode.hold);
      expect(row.codeOf("day-3"), OcptDayOutOfDaysCode.hold);
      expect(row.codeOf("day-5"), isNull);
      expect(row.workedDayCount, 2);
      expect(row.heldDayCount, 2);
    });
  });

  group("a role convoked on exactly one day", () {
    test("reads as start work finish rather than as a start with no end", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {}),
          _day(2, {"role-1"}),
          _day(3, {}),
        ],
        roleIds: const ["role-1"],
      );

      final row = table.rows.single;
      expect(row.codeByDayId, {"day-2": OcptDayOutOfDaysCode.startWorkFinish});
      expect(row.workedDayCount, 1);
      expect(row.heldDayCount, 0);
    });
  });

  group("which roles get a row", () {
    test("a role convoked nowhere in the range gets none", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {"role-1"}),
        ],
        roleIds: const ["role-1", "role-2"],
      );

      expect([for (final row in table.rows) row.roleId], ["role-1"]);
    });

    test("rows keep the order the roles were given in, not the order they start working", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {"role-2"}),
          _day(2, {"role-1"}),
        ],
        roleIds: const ["role-1", "role-2"],
      );

      expect([for (final row in table.rows) row.roleId], ["role-1", "role-2"]);
    });

    test("a role named twice by the caller gets one row", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {"role-1"}),
        ],
        roleIds: const ["role-1", "role-1"],
      );

      expect(table.rows.length, 1);
    });
  });

  group("the printed range", () {
    test("the columns are the days given, in that order", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(3, {"role-1"}),
          _day(1, {"role-1"}),
        ],
        roleIds: const ["role-1"],
      );

      expect(table.dayIds, ["day-3", "day-1"]);
      // "First" and "last" mean first and last in the order given, never by date: this file knows
      // no dates at all.
      expect(table.rows.single.codeOf("day-3"), OcptDayOutOfDaysCode.startWork);
      expect(table.rows.single.codeOf("day-1"), OcptDayOutOfDaysCode.workFinish);
    });

    test("a range starting mid-shoot reads its own first convoked day as a start", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(2, {"role-1"}),
          _day(3, {"role-1"}),
        ],
        roleIds: const ["role-1"],
      );

      expect(table.rows.single.codeOf("day-2"), OcptDayOutOfDaysCode.startWork);
    });
  });

  group("an empty table", () {
    test("no day at all computes to the empty table", () {
      final table = ocptComputeDayOutOfDays(days: const [], roleIds: const ["role-1"]);

      expect(table.isEmpty, isTrue);
      expect(table.dayIds, isEmpty);
      expect(table.rows, isEmpty);
    });

    test("days convoking nobody read as empty too", () {
      final table = ocptComputeDayOutOfDays(
        days: [
          _day(1, {}),
          _day(2, {}),
        ],
        roleIds: const ["role-1"],
      );

      expect(table.isEmpty, isTrue);
      expect(table.dayIds, ["day-1", "day-2"]);
    });
  });
}
