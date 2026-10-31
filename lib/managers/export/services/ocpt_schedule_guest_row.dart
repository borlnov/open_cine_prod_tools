// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';

/// One row of a day's own trailing guest table: a guest convocation's own display name, the
/// reason(s) their own `shooting_slot_guests` rows carry, and their own arrival – departure band.
/// **Never a PAT band** — a guest is not there to shoot (ADR 0018), so there is no field here to
/// carry one at all, unlike a crew or cast row's own.
///
/// Shared by `OcptCallSheetPdfService` and `OcptShootingPlanPdfService`, which both print this
/// exact table (`NOM / MOTIF / HORAIRES`) trailing their own timetable: the join belongs here for
/// the same reason [ocptScheduleBlockCaptionOf] does — two documents reading a guest's name, reason
/// and hours two different ways is exactly what this file exists to rule out. Each service keeps
/// only its own widget that draws the table, the section title and the labels object differing
/// between them.
class OcptScheduleGuestRow {
  /// Class constructor
  const OcptScheduleGuestRow({
    required this.name,
    required this.reason,
    required this.notes,
    required this.hours,
  });

  /// The guest's own display name — the address-book person's, the free name, or the
  /// `unnamedPersonLabel` [ocptScheduleGuestRowsOfDay] was given while neither names anybody
  /// printable.
  final String name;

  /// The distinct, non-empty reasons every `shooting_slot_guests` row naming this guest on one of
  /// their own slots carries, comma-joined — never picked down to one, since somebody attending two
  /// slots for two different reasons is telling the truth about both.
  final String reason;

  /// The same join over those rows' own free-form notes, printed under [reason] on a muted second
  /// line — empty when none of them carries any.
  final String notes;

  /// This guest's own arrival – departure band ([ocptScheduleArrivalDepartureLabel]).
  final String hours;
}
