// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';

/// A window during which a location may be shot in, with what qualifies it. See
/// `OcptLocationAvailabilitiesTable`'s doc comment for why it is a date range narrowed by weekdays
/// and crossed with a slot, and [OcptSet]'s for why it has no file of its own.
class OcptLocationAvailability extends Equatable {
  /// The stable, unique id of this window (a UUID).
  final String id;

  /// The location this window is about.
  final String locationId;

  /// The first date this window covers.
  final DateTime startDate;

  /// The last date this window covers, inclusive; the same as [startDate] for one day.
  final DateTime endDate;

  /// Which days of the week, inside the range, this window actually covers — the mask
  /// `ocptWeekdayMask*` reads (`lib/models/rules/ocpt_weekday_mask.dart`).
  final int weekdays;

  /// Which part of each covered day this window takes.
  final OcptDayPartSlot slot;

  /// The start of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;

  /// Whether the location may be used freely over this window, or only under the condition [note]
  /// spells out.
  final OcptLocationAvailabilityKind kind;

  /// What qualifies this window, free multi-line text.
  final String note;

  /// Class constructor
  const OcptLocationAvailability({
    required this.id,
    required this.locationId,
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.slot,
    required this.startMinute,
    required this.endMinute,
    required this.kind,
    required this.note,
  });

  /// Builds an [OcptLocationAvailability] from its stored [row].
  factory OcptLocationAvailability.fromRow(OcptLocationAvailabilityRow row) =>
      OcptLocationAvailability(
        id: row.id,
        locationId: row.locationId,
        startDate: row.startDate,
        endDate: row.endDate,
        weekdays: row.weekdays,
        slot: row.slot,
        startMinute: row.startMinute,
        endMinute: row.endMinute,
        kind: row.kind,
        note: row.note,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptLocationAvailability(id: $id, startDate: $startDate, endDate: $endDate, kind: $kind)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    locationId,
    startDate,
    endDate,
    weekdays,
    slot,
    startMinute,
    endMinute,
    kind,
    note,
  ];
}
