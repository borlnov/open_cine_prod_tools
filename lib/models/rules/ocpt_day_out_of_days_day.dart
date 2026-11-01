// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_day_out_of_days.dart';

/// One day of the printed range, as fed to [ocptComputeDayOutOfDays]: its own id and the roles it
/// convokes.
///
/// [convokedRoleIds] names **roles**, never actors: a *Day Out of Days* is negotiated per part, an
/// uncast role is exactly as scheduled as a cast one, and recasting must not redraw this table. It
/// is a fact about the day as a whole, joined across every one of its slots by the caller — this
/// file knows nothing of slots, of `shooting_slot_cast` or of drift.
class OcptDayOutOfDaysDay {
  /// The day's own id (`shooting_days.id`).
  final String id;

  /// The ids of every role this day convokes, on any of its own slots.
  final Set<String> convokedRoleIds;

  /// Class constructor
  const OcptDayOutOfDaysDay({required this.id, required this.convokedRoleIds});
}
