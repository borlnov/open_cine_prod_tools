// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_out_of_days.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_out_of_days_code.dart';

/// One role's own row of the table: its code on each day it has one, and the two counts a printed
/// row trails.
///
/// [codeByDayId] holds an entry **only inside the role's own span** — from its first convoked day
/// of the printed range to its last, inclusive. A day before the first or after the last carries no
/// entry at all rather than a code meaning "not working": the role is simply not on this shoot yet,
/// or no longer is, and a mark there would be a claim about days the production has not committed.
class OcptDayOutOfDaysRow extends Equatable {
  /// The role this row is about (`roles.id`).
  final String roleId;

  /// This role's own code per day, keyed by `shooting_days.id` — see the class doc comment for why
  /// a day outside its span has no entry.
  final Map<String, OcptDayOutOfDaysCode> codeByDayId;

  /// How many days of the printed range this role is convoked on — every cell but
  /// [OcptDayOutOfDaysCode.hold], so always at least 1 (a row exists only for a role convoked
  /// somewhere, see [ocptComputeDayOutOfDays]).
  final int workedDayCount;

  /// How many [OcptDayOutOfDaysCode.hold] days this role's own span holds — the days it is owed
  /// without being called.
  final int heldDayCount;

  /// Class constructor
  const OcptDayOutOfDaysRow({
    required this.roleId,
    required this.codeByDayId,
    required this.workedDayCount,
    required this.heldDayCount,
  });

  /// This role's own code on [dayId], or null when [dayId] falls outside its span.
  OcptDayOutOfDaysCode? codeOf(String dayId) => codeByDayId[dayId];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptDayOutOfDaysRow(roleId: $roleId, worked: $workedDayCount, held: $heldDayCount)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [roleId, codeByDayId, workedDayCount, heldDayCount];
}
