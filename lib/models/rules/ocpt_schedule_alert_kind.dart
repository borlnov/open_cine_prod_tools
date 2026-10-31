// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_severity.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_anchor_cycle.dart';

/// What went wrong, one entry per rule [ocptComputeScheduleAlerts] implements.
///
/// **Ten rules are here.** An eleventh — a key position left unfilled in a slot — is deliberately
/// not implemented: nothing in this app says which position on a film is "key" (a first assistant
/// camera matters as much as a director of photography on the day their own department is the
/// bottleneck), and a list invented for the occasion would read as the app's own opinion rather
/// than the production's. No alert is better than a wrong one here.
///
/// A **position lost between two consecutive slots** was once the fourth of them and is
/// deliberately gone: a crew that changes between a morning unit and an afternoon one is what slots
/// are *for*, and reading every such change as something to look at made the panel cry wolf on the
/// ordinary case. That a position is held on one slot and not the next is already visible, without
/// a sentence, in the positions matrix's own column-by-column reading.
///
/// [OcptTimelineAnchorCycle] (`ocpt_shooting_day_timeline.dart`) is likewise **not** one of the
/// ten, and deliberately so: the anchor picker already refuses to offer an entry that would
/// close a cycle (`ocptSlotAnchorWouldCycle`) and `OcptScheduleService.setSlotAnchor` refuses to
/// write one. A cycle is defence against a hand-edited file, not a state this app's own UI can put
/// a user in, and an alert for a state nobody can reach would only ever fire on data this app
/// didn't write.
///
/// **Nothing here reads what a day holds beyond its own slots and blocks**, and that is the point:
/// a day that rehearses in the morning and shoots in the afternoon is one day, a rehearsal the day
/// before a 07:00 call eats the same turnaround shooting would, and a person double-booked is
/// double-booked whatever the two slots were for. The one rule that has nothing to say about a day
/// spent auditioning — [OcptScheduleRoleNotConvokedAlert], about a role a **placed shot** plays —
/// needs no special case: a day carrying no shot block calls no role, so the rule simply finds
/// nothing.
///
/// A **candidate convoked to be seen for a part** takes part in **no rule at all**, on the very
/// argument that already keeps a guest out of every one of them: they hold no position to lose,
/// have no daily maximum of the production's making, and are not cast. They are owed an hour, which
/// the convocations panel and the call sheet both give them, and nothing here is about an hour —
/// every rule of this file is about somebody's *work*. An eleventh rule for them ("a candidate
/// convoked on no slot") would be an opinion about how a production runs its auditions, and is
/// deliberately not written.
///
/// Declaration order here is also the tie-break order [ocptComputeScheduleAlerts] sorts by once
/// severity and day agree — see that function's own doc comment.
enum OcptScheduleAlertKind {
  /// [OcptSchedulePersonUnavailableAlert].
  personUnavailable(OcptScheduleAlertSeverity.hard),

  /// [OcptSchedulePersonDoubleBookedAlert].
  personDoubleBooked(OcptScheduleAlertSeverity.hard),

  /// [OcptScheduleLocationUncoveredAlert].
  locationUncovered(OcptScheduleAlertSeverity.hard),

  /// [OcptScheduleRoleNotConvokedAlert].
  roleNotConvoked(OcptScheduleAlertSeverity.soft),

  /// [OcptScheduleRoleUncastAlert].
  roleUncast(OcptScheduleAlertSeverity.soft),

  /// [OcptScheduleTimelineOverrunAlert].
  timelineOverrun(OcptScheduleAlertSeverity.soft),

  /// [OcptScheduleFixedEndMissedAlert].
  slotFixedEndMissed(OcptScheduleAlertSeverity.soft),

  /// [OcptSchedulePresenceExceededAlert].
  presenceExceeded(OcptScheduleAlertSeverity.soft),

  /// [OcptScheduleRestTimeAlert].
  restTime(OcptScheduleAlertSeverity.soft),

  /// [OcptSchedulePermitNotValidAlert].
  permitNotValid(OcptScheduleAlertSeverity.soft);

  /// Class constructor
  const OcptScheduleAlertKind(this.severity);

  /// How urgently this kind of alert needs a human to look at it.
  final OcptScheduleAlertSeverity severity;
}
