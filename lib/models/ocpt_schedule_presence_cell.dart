// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';

/// One cell of the presence grid — `OcptSchedulePlanSnapshot.presenceCellOf`'s own answer for one
/// (day, person) pair.
///
/// [code] is null for a **blank** cell: neither a live override nor either of the two computed
/// readings applies, which is absence of information and is drawn as no pill at all
/// (`OcptSchedulePresenceGrid`'s own doc comment) — never as a fifth code. [isOverridden] is true
/// exactly when [code] came from a live `shooting_presences` row rather than being computed; nothing
/// in the grid paints the two differently today, but the distinction is what the click cycle
/// (`ocptNextPresenceOverride`) steps from, so it travels with the cell rather than being
/// re-derived at the click site.
class OcptSchedulePresenceCell extends Equatable {
  /// This cell's own effective code, or null for a blank cell.
  final OcptPresenceCode? code;

  /// Whether [code] came from a live override rather than being computed.
  final bool isOverridden;

  /// Class constructor
  const OcptSchedulePresenceCell({required this.code, required this.isOverridden});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptSchedulePresenceCell(code: $code, isOverridden: $isOverridden)";

  /// Object properties
  @override
  List<Object?> get props => [code, isOverridden];
}
