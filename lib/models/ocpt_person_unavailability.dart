// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_skill.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';

/// A stretch of time a person is known to be unavailable, with a reason. See [OcptPersonSkill]'s
/// doc comment for why this has no file of its own either, and
/// `OcptPersonUnavailabilitiesTable`'s for why it is a date range crossed with a slot.
class OcptPersonUnavailability extends Equatable {
  /// The stable, unique id of this unavailability (a UUID).
  final String id;

  /// The person who is unavailable.
  final String personId;

  /// The first date this unavailability covers.
  final DateTime startDate;

  /// The last date this unavailability covers, inclusive; the same as [startDate] for one day.
  final DateTime endDate;

  /// Which part of each covered day this unavailability takes.
  final OcptDayPartSlot slot;

  /// The start of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;

  /// Why this person is unavailable, free multi-line text.
  final String reason;

  /// Class constructor
  const OcptPersonUnavailability({
    required this.id,
    required this.personId,
    required this.startDate,
    required this.endDate,
    required this.slot,
    required this.startMinute,
    required this.endMinute,
    required this.reason,
  });

  /// Builds an [OcptPersonUnavailability] from its stored [row].
  factory OcptPersonUnavailability.fromRow(OcptPersonUnavailabilityRow row) =>
      OcptPersonUnavailability(
        id: row.id,
        personId: row.personId,
        startDate: row.startDate,
        endDate: row.endDate,
        slot: row.slot,
        startMinute: row.startMinute,
        endMinute: row.endMinute,
        reason: row.reason,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptPersonUnavailability(id: $id, startDate: $startDate, endDate: $endDate, slot: $slot)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    id,
    personId,
    startDate,
    endDate,
    slot,
    startMinute,
    endMinute,
    reason,
  ];
}
