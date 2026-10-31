// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_marker.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';

/// Where an event's own marker sits relative to the grid's own `[startMinute, endMinute)` band —
/// see [OcptShootingDayAgendaGrid]'s own doc comment for why the grid's bounds no longer stretch to
/// reach one, unlike the schedule mode's own on-screen week grid.
enum OcptShootingDayAgendaEventPlacement {
  /// The event's own minute falls strictly before [OcptShootingDayAgendaGrid.startMinute]: drawn as
  /// a leading marker above the grid, adjacent to its first row, with no blank row in between.
  /// [OcptShootingDayAgendaEventMarker.row] is null.
  beforeGrid,

  /// The event's own minute falls inside `[startMinute, endMinute)`: drawn as a full-width marker
  /// on its own [OcptShootingDayAgendaEventMarker.row], exactly as before this placement existed.
  inGrid,

  /// The event's own minute falls at or after [OcptShootingDayAgendaGrid.endMinute]: drawn as a
  /// trailing marker below the grid, adjacent to its last row, with no blank row in between.
  /// [OcptShootingDayAgendaEventMarker.row] is null.
  ///
  /// The boundary is deliberately inclusive of [OcptShootingDayAgendaGrid.endMinute] itself: a row
  /// covers `[start, start + stepMinutes)`, so `endMinute` is one past the last row's own last
  /// minute rather than a minute any row contains — an event landing exactly there has nothing to
  /// sit on and reads as just after the band, not as part of it.
  afterGrid,
}
