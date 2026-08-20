// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

/// How urgently an [OcptScheduleAlert] needs a human to look at it.
///
/// A property of the *kind* ([OcptScheduleAlertKind.severity]), never of one occurrence: a
/// double-booked person is exactly as hard an alert on a quiet Tuesday as on the busiest day of the
/// shoot, so nothing here is computed per instance.
enum OcptScheduleAlertSeverity {
  /// The plan, as written, cannot be shot the way it stands — somebody is asked to be in two places
  /// at once, or a location isn't cleared for the slot booked in it.
  hard,

  /// The plan is shootable but worth a second look before the day arrives — a position quietly
  /// dropped, a role nobody has cast yet, a figure the app computed running past what was recorded
  /// for it.
  soft,
}

/// What went wrong, one entry per rule [ocptComputeScheduleAlerts] implements.
///
/// **Ten rules are here.** An eleventh — a key position left unfilled in a slot — is deliberately
/// not implemented: nothing in this app says which position on a film is "key" (a first assistant
/// camera matters as much as a director of photography on the day their own department is the
/// bottleneck), and a list invented for the occasion would read as the app's own opinion rather
/// than the production's. No alert is better than a wrong one here.
///
/// A **position lost between two consecutive slots** was once the fourth of them and is deliberately
/// gone: a crew that changes between a morning unit and an afternoon one is what slots are *for*,
/// and reading every such change as something to look at made the panel cry wolf on the ordinary
/// case. That a position is held on one slot and not the next is already visible, without a
/// sentence, in the positions matrix's own column-by-column reading.
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

/// One thing [ocptComputeScheduleAlerts] found wrong with the plan.
///
/// A sealed hierarchy rather than one class with a dozen nullable fields, so a panel reading these
/// switches over [OcptScheduleAlert] exhaustively and never has to guess which fields a given
/// [kind] actually fills in. **It knows no names**: every subclass carries ids and figures alone —
/// a person's id, a role's id, a minute — and it is the panel that resolves a person's display name
/// or localises a sentence around them, exactly as `OcptDayConvocation` carries no name either.
sealed class OcptScheduleAlert {
  /// Class constructor
  const OcptScheduleAlert({required this.dayId});

  /// The day this alert is about, or null for [OcptScheduleRoleUncastAlert] alone — a role's own
  /// casting is not a fact about any one day.
  final String? dayId;

  /// Which of the ten rules raised this alert.
  OcptScheduleAlertKind get kind;

  /// [kind]'s own [OcptScheduleAlertKind.severity].
  OcptScheduleAlertSeverity get severity => kind.severity;
}

/// **Hard, rule 1**: [personId] is linked to at least one slot of [dayId], and one of their
/// recorded [OcptScheduleAlertUnavailability]s ([unavailabilityId]) covers that day's date over a
/// day part that overlaps one or more of those slots' own resolved bands — [slotIds], in the day's
/// own order.
///
/// A [OcptDayPartSlot.fullDay] window always covers every slot the person is linked to that day —
/// see [ocptComputeScheduleAlerts]'s own doc comment for how [OcptDayPartSlot.morning] and
/// [OcptDayPartSlot.afternoon] read a slot whose band runs past midnight.
final class OcptSchedulePersonUnavailableAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptSchedulePersonUnavailableAlert({
    required super.dayId,
    required this.personId,
    required this.unavailabilityId,
    required this.slotIds,
  });

  /// The person who is unavailable.
  final String personId;

  /// The [OcptScheduleAlertUnavailability.id] whose window this alert is about.
  final String unavailabilityId;

  /// The slots of [OcptScheduleAlert.dayId] this person is linked to whose own band the
  /// unavailability's day part actually overlaps, in the day's own order. Never empty: an alert
  /// with nothing in it is not raised at all.
  final List<String> slotIds;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.personUnavailable;
}

/// **Hard, rule 2**: [personId] is linked to both [firstSlotId] and [secondSlotId] of [dayId], and
/// the two slots' own resolved bands overlap in wall-clock time — strictly: two slots merely
/// meeting end-to-start never raise this.
///
/// Two *slots* overlapping is legal and ordinary — that is what splitting a day into slots is for.
/// One *person* being linked to both at once is not: nobody can be in two places at the same
/// minute. A slot carrying no block at all (whose own resolved end is null) never overlaps anything
/// under this rule — it has no band yet to compare, so it stays silent rather than reading a zero-
/// length placeholder as a conflict.
final class OcptSchedulePersonDoubleBookedAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptSchedulePersonDoubleBookedAlert({
    required super.dayId,
    required this.personId,
    required this.firstSlotId,
    required this.secondSlotId,
  });

  /// The person linked to both slots at once.
  final String personId;

  /// The earlier of the two slots, in the day's own order.
  final String firstSlotId;

  /// The later of the two slots, in the day's own order.
  final String secondSlotId;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.personDoubleBooked;
}

/// **Hard, rule 3**: [slotId]'s own location ([locationId]) declares at least one
/// [OcptScheduleAlertLocationWindow], and none of them covers [slotId]'s own resolved band on
/// [OcptScheduleAlert.dayId]'s date.
///
/// **A location that declares no window at all raises nothing.** Absence of data is not a refusal
/// to shoot there — a project that has never entered a single availability for a location must not
/// be drowned in one alert per slot booked in it. This is the rule most likely to be "fixed"
/// backwards later, so it is stated here twice.
final class OcptScheduleLocationUncoveredAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptScheduleLocationUncoveredAlert({
    required super.dayId,
    required this.slotId,
    required this.locationId,
  });

  /// The slot whose booking no declared window covers.
  final String slotId;

  /// The location [slotId] is booked at.
  final String locationId;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.locationUncovered;
}

/// **Soft, rule 4**: [roleId] is called for by [shotId], a shot placed on [OcptScheduleAlert.dayId],
/// and [roleId] is convoked (cast or not) on none of that day's slots.
///
/// One alert per (day, role): a role called for by three shots of the same day that is convoked
/// nowhere raises exactly one alert, carrying one of those shots — never three. Matching a shot's
/// characters to a role is a join over `fountain_kit`'s `normalizeCharacterName`, done by the
/// caller before this file ever sees a shot or a character name.
final class OcptScheduleRoleNotConvokedAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptScheduleRoleNotConvokedAlert({
    required super.dayId,
    required this.roleId,
    required this.shotId,
  });

  /// The role a placed shot calls for and no slot of the day convokes.
  final String roleId;

  /// One of the shots of this day that calls for [roleId] — the first the caller listed, not
  /// necessarily the only one.
  final String shotId;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.roleNotConvoked;
}

/// **Soft, rule 5**: [roleId] has no actor (`roles.personId` is null), and it is a role the
/// schedule actually uses — cast on some slot of some day, or called for by a shot placed
/// somewhere.
///
/// [OcptScheduleAlert.dayId] is always null: a role's casting is a fact about the role, not about
/// one day. Restricted to roles the schedule uses on purpose — a project whose casting hasn't
/// started yet would otherwise raise one of these per role in the whole cast, for nothing anybody
/// can act on before a single day exists.
final class OcptScheduleRoleUncastAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptScheduleRoleUncastAlert({required this.roleId}) : super(dayId: null);

  /// The role with no actor.
  final String roleId;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.roleUncast;
}

/// **Soft, rule 6**: a straight pass-through of one [OcptTimelineOverrun] on
/// [OcptScheduleAlert.dayId] — a pinned block the day's own chain could not reach without overlap
/// (ADR 0015, as amended).
final class OcptScheduleTimelineOverrunAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptScheduleTimelineOverrunAlert({
    required super.dayId,
    required this.blockId,
    required this.reachedMinute,
    required this.anchorMinute,
  });

  /// The [OcptTimelineOverrun.blockId] whose anchor could not be honoured.
  final String blockId;

  /// The minute the chain had reached, right before this block pinned it back.
  final int reachedMinute;

  /// The anchor the block was pinned to, which [reachedMinute] ran past.
  final int anchorMinute;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.timelineOverrun;
}

/// **Soft, rule 7**: a straight pass-through of one [OcptTimelineFixedEndMiss] on
/// [OcptScheduleAlert.dayId] — an end-anchored slot whose own blocks did not land back on the fixed
/// end that anchored them (ADR 0015, as amended twice).
final class OcptScheduleFixedEndMissedAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptScheduleFixedEndMissedAlert({
    required super.dayId,
    required this.slotId,
    required this.fixedEndMinute,
    required this.actualEndMinute,
  });

  /// The [OcptTimelineFixedEndMiss.slotId] whose fixed end its own blocks did not land on.
  final String slotId;

  /// The hour the slot's own end anchor resolved to.
  final int fixedEndMinute;

  /// The minute the slot's chain actually ends at.
  final int actualEndMinute;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.slotFixedEndMissed;
}

/// **Soft, rule 8**: on [OcptScheduleAlert.dayId], [personId]'s own computed presence
/// ([presenceMinutes] — the day's own convocation departure minus arrival, joined across every
/// slot they are linked to, ADR 0018) exceeds the maximum recorded for them
/// (`people.maxDailyPresenceMinutes`, [maxDailyPresenceMinutes]).
///
/// Fires only when that column is filled **and** exceeded — never when it is null, which means
/// "nobody has recorded one" rather than "no limit applies". Not restricted to minors: the column
/// isn't either, so neither is this alert. A presence exactly equal to the recorded maximum does
/// not fire.
final class OcptSchedulePresenceExceededAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptSchedulePresenceExceededAlert({
    required super.dayId,
    required this.personId,
    required this.presenceMinutes,
    required this.maxDailyPresenceMinutes,
  });

  /// The person whose day ran long.
  final String personId;

  /// This person's own computed presence on this day, in minutes: departure minus arrival.
  final int presenceMinutes;

  /// The maximum recorded for this person, in minutes — the figure [presenceMinutes] exceeds.
  final int maxDailyPresenceMinutes;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.presenceExceeded;
}

/// **Soft, rule 9**: [personId]'s own departure on [previousDayId] and their arrival on
/// [OcptScheduleAlert.dayId] — the **next day they are actually convoked on**, not necessarily the
/// next calendar date — are closer together than [minimumRestMinutes]
/// (`project_info.minimumRestMinutes`).
///
/// Grouped onto the **second** of the two days: the call that comes too soon is the one a
/// production would move, not the wrap that came before it. [restMinutes] is the actual gap,
/// crossing midnight honestly (ADR 0015): a night day ending at 03:00 (stored 1620) followed by a
/// 07:00 call the next date is a 240-minute gap, never a negative figure and never wrapped modulo a
/// day.
///
/// **Silent when [minimumRestMinutes] is null** — nobody has recorded one for the project, never
/// "no minimum applies" — the exact reading `people.maxDailyPresenceMinutes` already has for
/// [OcptSchedulePresenceExceededAlert].
final class OcptScheduleRestTimeAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptScheduleRestTimeAlert({
    required super.dayId,
    required this.personId,
    required this.previousDayId,
    required this.restMinutes,
    required this.minimumRestMinutes,
  });

  /// The person whose rest between two convoked days fell short.
  final String personId;

  /// The earlier of the two days — the one [personId] wrapped on.
  final String previousDayId;

  /// The actual gap between [previousDayId]'s own departure and [OcptScheduleAlert.dayId]'s own
  /// arrival, in minutes — always less than [minimumRestMinutes].
  final int restMinutes;

  /// The minimum recorded for the project (`project_info.minimumRestMinutes`), in minutes — the
  /// figure [restMinutes] fell short of.
  final int minimumRestMinutes;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.restTime;
}

/// **Soft, rule 10**: [slotId]'s own location ([locationId]) declares at least one dated
/// [OcptSchedulePermitWindow], and none of them covers [OcptScheduleAlert.dayId]'s own calendar
/// date.
///
/// Named for what it actually claims rather than for the shape of the data behind it: a location
/// that files **no** permit at all raises nothing — see [ocptComputeScheduleAlerts]'s own reading
/// of [OcptSchedulePermitWindow] for why "no permit on file" and "a permit that doesn't cover this
/// date" must never be read as the same thing, the way rule 3 already keeps "no availability
/// window" apart from "a window that doesn't cover this slot".
final class OcptSchedulePermitNotValidAlert extends OcptScheduleAlert {
  /// Class constructor
  const OcptSchedulePermitNotValidAlert({
    required super.dayId,
    required this.slotId,
    required this.locationId,
  });

  /// The slot whose booking no dated permit window covers.
  final String slotId;

  /// The location [slotId] is booked at.
  final String locationId;

  /// This alert's own kind.
  @override
  OcptScheduleAlertKind get kind => OcptScheduleAlertKind.permitNotValid;
}

/// One slot of a day, already resolved by the caller (`OcptSchedulePlanSnapshot`, never this file,
/// which knows nothing of drift or of `shooting_slots`/`shooting_slot_crew`/`shooting_slot_cast`)
/// into exactly what the day-level rules need: its own resolved band, its location, and who is
/// convoked on it and how.
class OcptScheduleAlertSlot {
  /// Builds a slot to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertSlot({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    required this.locationId,
    required this.personIds,
    required this.convokedRoleIds,
  });

  /// The slot's own id (`shooting_slots.id`), echoed back on every alert that names it.
  final String id;

  /// The slot's own resolved start (`OcptShootingSlotTimeline.startMinute`), never a stored column.
  final int startMinute;

  /// The slot's own resolved end (`OcptShootingSlotTimeline.endMinute`), or null while it carries
  /// no block at all — see [OcptSchedulePersonDoubleBookedAlert]'s own doc comment for what that
  /// means to rule 2; every other rule reads an empty band as `endMinute ?? startMinute`, exactly
  /// as `ocptComputeDayConvocations` reads a departure.
  final int? endMinute;

  /// The location this slot is booked at, or null while none is chosen — a slot naming none is
  /// skipped by the location-coverage rule, there being nothing to check.
  final String? locationId;

  /// Every person convoked on this slot as a human: its own crew rows' people, plus the actors of
  /// its cast roles that are cast — mirroring `OcptConvocationSlot.personIds`.
  final Set<String> personIds;

  /// Every role convoked on this slot, cast or not — `OcptShootingSlotCastMember.roleId` verbatim.
  /// Unlike [personIds], which only ever names a human, an entry here may point at a role nobody
  /// has cast yet.
  final Set<String> convokedRoleIds;
}

/// One role a placed shot calls for on a given day — the caller's own join of a shot's characters
/// onto the cast, through `fountain_kit`'s `normalizeCharacterName`. This file knows nothing of
/// shots or characters beyond "[roleId] is wanted for [shotId]".
class OcptScheduleAlertCalledRole {
  /// Builds a called role to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertCalledRole({required this.roleId, required this.shotId});

  /// The role a placed shot calls for.
  final String roleId;

  /// The shot that calls for [roleId].
  final String shotId;
}

/// One person's unavailability window, reduced to what [OcptSchedulePersonUnavailableAlert] needs
/// — the mirror of `OcptPersonUnavailability`, minus the person's own id (the caller already groups
/// these under [OcptScheduleAlertPerson]) and the free-text reason, which this file never reads.
class OcptScheduleAlertUnavailability {
  /// Builds an unavailability window to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertUnavailability({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.dayPart,
    required this.startMinute,
    required this.endMinute,
  });

  /// This window's own id, echoed back on [OcptSchedulePersonUnavailableAlert.unavailabilityId].
  final String id;

  /// The first date this window covers.
  final DateTime startDate;

  /// The last date this window covers, inclusive.
  final DateTime endDate;

  /// Which part of each covered day this window takes.
  final OcptDayPartSlot dayPart;

  /// The start of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;
}

/// One person of the address book, reduced to what rules 1 and 9 need about a human: their own
/// [unavailabilities] and their recorded [maxDailyPresenceMinutes].
class OcptScheduleAlertPerson {
  /// Builds a person to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertPerson({
    required this.id,
    required this.maxDailyPresenceMinutes,
    required this.unavailabilities,
  });

  /// The person's own id, matched against a slot's own [OcptScheduleAlertSlot.personIds].
  final String id;

  /// `people.maxDailyPresenceMinutes` verbatim — null while nobody has recorded one, which
  /// [OcptSchedulePresenceExceededAlert] never fires on.
  final int? maxDailyPresenceMinutes;

  /// This person's own recorded unavailabilities, in no particular order.
  final List<OcptScheduleAlertUnavailability> unavailabilities;
}

/// One role of the cast, reduced to what [OcptScheduleRoleUncastAlert] needs: whether it has an
/// actor.
class OcptScheduleAlertRole {
  /// Builds a role to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertRole({required this.id, required this.personId});

  /// The role's own id.
  final String id;

  /// The actor cast in this role, or null while it is uncast — `roles.personId` verbatim.
  final String? personId;
}

/// One availability window of a location, reduced to what [OcptScheduleLocationUncoveredAlert]
/// needs — the mirror of `OcptLocationAvailability`, minus `OcptLocationAvailabilityKind` (both of
/// its values count as covering, so the caller need not even resolve which one this is) and its
/// free-text note.
class OcptScheduleAlertLocationWindow {
  /// Builds a location window to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertLocationWindow({
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.dayPart,
    required this.startMinute,
    required this.endMinute,
  });

  /// The first date this window covers.
  final DateTime startDate;

  /// The last date this window covers, inclusive.
  final DateTime endDate;

  /// Which days of the week, inside the range, this window covers — the mask `ocptWeekdayMask*`
  /// reads (`lib/utils/ocpt_weekday_mask.dart`).
  final int weekdays;

  /// Which part of each covered day this window takes.
  final OcptDayPartSlot dayPart;

  /// The start of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;
}

/// One permit window a location declares, reduced to what [OcptSchedulePermitNotValidAlert] needs
/// — the mirror of `OcptAssetRef.validFrom`/`validUntil`, a document's own validity dates rather
/// than a whole asset row, mirroring how [OcptScheduleAlertLocationWindow] strips
/// `OcptLocationAvailability` down to what rule 3 reads.
///
/// **A window with both dates null records nothing and is not a window at all** — the caller must
/// not hand one in, and [ocptComputeScheduleAlerts] filters one out defensively (belt and braces)
/// rather than trusting every caller to have done so: a location whose every recorded permit is
/// dateless reads exactly as one that filed none, the same "absence of data is not a refusal"
/// argument rule 3 already makes for a location declaring no availability window at all.
class OcptSchedulePermitWindow {
  /// Builds a permit window to feed to [ocptComputeScheduleAlerts].
  const OcptSchedulePermitWindow({required this.validFrom, required this.validUntil});

  /// The date this permit becomes valid, or null while unbounded on that side.
  final DateTime? validFrom;

  /// The date this permit stops being valid, or null while unbounded on that side.
  final DateTime? validUntil;
}

/// One day, joined by the caller into everything the ten rules read about it.
class OcptScheduleAlertDay {
  /// Builds a day to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertDay({
    required this.id,
    required this.date,
    required this.slots,
    required this.overruns,
    required this.fixedEndMisses,
    required this.calledRoles,
  });

  /// This day's own id.
  final String id;

  /// This day's own calendar date — what rules 1 and 3 cross against a window's date range and
  /// weekday mask.
  final DateTime date;

  /// This day's own live slots, in **resolved-start order**: rule 2 names the earlier and the later
  /// of two overlapping slots out of this list's own order, so the caller orders it, not this file.
  final List<OcptScheduleAlertSlot> slots;

  /// This day's own [OcptShootingDayTimelines.overruns], passed straight through by rule 6.
  final List<OcptTimelineOverrun> overruns;

  /// This day's own [OcptShootingDayTimelines.fixedEndMisses], passed straight through by rule 7.
  final List<OcptTimelineFixedEndMiss> fixedEndMisses;

  /// Every role a shot placed on this day calls for, in the order the caller found them — rule 4
  /// keeps the first [OcptScheduleAlertCalledRole.shotId] it meets for a given role and ignores the
  /// rest.
  final List<OcptScheduleAlertCalledRole> calledRoles;
}

/// The minute at which [OcptDayPartSlot.morning] ends and [OcptDayPartSlot.afternoon] begins:
/// 13:00, the same split the schedule mode's day-part pickers already offer.
const int _dayPartSplitMinute = 13 * 60;

/// Computes every [OcptScheduleAlert] the ten rules raise over [days], [people], [roles],
/// [locationWindowsByLocationId], [minimumRestMinutes] and [permitWindowsByLocationId] — the
/// schedule mode's alert computation, implemented exactly once, here.
///
/// Every join a rule needs onto `shots`, `roles`, `people` or `locations` is the caller's job
/// (`OcptSchedulePlanSnapshot`, never this file): this function reads only the already-resolved
/// figures [OcptScheduleAlertDay] and its nested types carry, exactly as
/// `ocptComputeDayConvocations` and `ocptComputeShootingDayTimelines` do for their own joins.
///
/// **A band running past midnight is never wrapped.** [OcptDayPartSlot.afternoon] has no upper
/// bound — it covers `[13:00, →)` — so a night slot running to 03:00 the next morning (stored as
/// 1620, ADR 0015) reads as squarely inside "afternoon" for however far past 1440 it runs, while
/// [OcptDayPartSlot.morning] (`[00:00, 13:00)`) never reaches it. This is a deliberate reading, not
/// an oversight: a shooting day's own "morning" and "afternoon" are about that day's own shoot, not
/// about which real calendar date the clock face happens to say once a slot crosses midnight, and a
/// window's date range is always resolved against [OcptScheduleAlertDay.date] alone — never against
/// a second, later calendar date a night slot's tail technically falls on.
///
/// [minimumRestMinutes] is `project_info.minimumRestMinutes` verbatim: **null means nobody has
/// recorded one**, and rule 9 raises nothing at all rather than assuming a legal minimum this app
/// never validated — the same reading a person's own `maxDailyPresenceMinutes` already has for
/// rule 8.
///
/// The result is sorted **hard alerts before soft**, then by the day order [days] was given (an
/// alert with no day — [OcptScheduleRoleUncastAlert] alone — sorts after every real day of the same
/// severity), then by [OcptScheduleAlertKind]'s own declaration order, then by the alert's own ids
/// — deterministic, and pinned by a test, since this is the order a panel would show the list in.
List<OcptScheduleAlert> ocptComputeScheduleAlerts({
  required List<OcptScheduleAlertDay> days,
  required List<OcptScheduleAlertPerson> people,
  required List<OcptScheduleAlertRole> roles,
  required Map<String, List<OcptScheduleAlertLocationWindow>> locationWindowsByLocationId,
  required int? minimumRestMinutes,
  required Map<String, List<OcptSchedulePermitWindow>> permitWindowsByLocationId,
}) {
  final alerts = <OcptScheduleAlert>[];

  _addPersonUnavailableAlerts(alerts, days, people);
  _addPersonDoubleBookedAlerts(alerts, days);
  _addLocationUncoveredAlerts(alerts, days, locationWindowsByLocationId);
  _addRoleNotConvokedAlerts(alerts, days);
  _addRoleUncastAlerts(alerts, days, roles);
  _addTimelineAlerts(alerts, days);
  _addPresenceExceededAlerts(alerts, days, people);
  _addRestTimeAlerts(alerts, days, people, minimumRestMinutes);
  _addPermitNotValidAlerts(alerts, days, permitWindowsByLocationId);

  final dayIndexById = {for (var index = 0; index < days.length; index++) days[index].id: index};
  int dayIndexOf(String? dayId) =>
      dayId == null ? days.length : (dayIndexById[dayId] ?? days.length);

  alerts.sort((left, right) {
    final bySeverity = left.severity.index.compareTo(right.severity.index);
    if (bySeverity != 0) {
      return bySeverity;
    }
    final byDay = dayIndexOf(left.dayId).compareTo(dayIndexOf(right.dayId));
    if (byDay != 0) {
      return byDay;
    }
    final byKind = left.kind.index.compareTo(right.kind.index);
    if (byKind != 0) {
      return byKind;
    }
    return _tieBreakKeyOf(left).compareTo(_tieBreakKeyOf(right));
  });

  return alerts;
}

/// [alerts] grouped by the day each of them concerns, every group keeping the order it was given —
/// what a day-level indicator (a day card, an agenda cell, the day view's own summary band) reads
/// to say, without leaving the surface it is on, that this day has something wrong with it.
///
/// An alert carrying no day — [OcptScheduleRoleUncastAlert] alone — belongs to **no** group: a
/// role's own casting is a fact about the role rather than about any one day, so pinning it onto
/// every day the role plays would make a project-wide gap read as a dozen separate day problems.
/// It is counted by the status bar and listed in the alerts panel, exactly as before, and simply
/// marks no day.
///
/// A day raising nothing at all has **no entry**, rather than an empty list: absence and emptiness
/// read the same here, and a caller reaching for a day's own alerts is looking up a map by id.
Map<String, List<OcptScheduleAlert>> ocptGroupScheduleAlertsByDay(List<OcptScheduleAlert> alerts) {
  final grouped = <String, List<OcptScheduleAlert>>{};
  for (final alert in alerts) {
    final dayId = alert.dayId;
    if (dayId == null) {
      continue;
    }
    (grouped[dayId] ??= <OcptScheduleAlert>[]).add(alert);
  }
  return grouped;
}

/// The string the final sort ties two same-day, same-kind alerts on — an exhaustive switch, so an
/// eleventh [OcptScheduleAlert] subclass cannot be added without this file being told how to order
/// it.
String _tieBreakKeyOf(OcptScheduleAlert alert) => switch (alert) {
  OcptSchedulePersonUnavailableAlert(:final personId, :final unavailabilityId) =>
    "$personId|$unavailabilityId",
  OcptSchedulePersonDoubleBookedAlert(:final personId, :final firstSlotId, :final secondSlotId) =>
    "$personId|$firstSlotId|$secondSlotId",
  OcptScheduleLocationUncoveredAlert(:final slotId, :final locationId) => "$slotId|$locationId",
  OcptScheduleRoleNotConvokedAlert(:final roleId, :final shotId) => "$roleId|$shotId",
  OcptScheduleRoleUncastAlert(:final roleId) => roleId,
  OcptScheduleTimelineOverrunAlert(:final blockId) => blockId,
  OcptScheduleFixedEndMissedAlert(:final slotId) => slotId,
  OcptSchedulePresenceExceededAlert(:final personId) => personId,
  OcptScheduleRestTimeAlert(:final personId, :final previousDayId) => "$personId|$previousDayId",
  OcptSchedulePermitNotValidAlert(:final slotId, :final locationId) => "$slotId|$locationId",
};

/// Rule 1: a person convoked on a day they recorded an unavailability for, honouring the window's
/// own day part against every slot they are linked to that day.
void _addPersonUnavailableAlerts(
  List<OcptScheduleAlert> alerts,
  List<OcptScheduleAlertDay> days,
  List<OcptScheduleAlertPerson> people,
) {
  final peopleById = {for (final person in people) person.id: person};

  for (final day in days) {
    final slotsByPersonId = <String, List<OcptScheduleAlertSlot>>{};
    for (final slot in day.slots) {
      for (final personId in slot.personIds) {
        (slotsByPersonId[personId] ??= <OcptScheduleAlertSlot>[]).add(slot);
      }
    }

    for (final entry in slotsByPersonId.entries) {
      final person = peopleById[entry.key];
      if (person == null) {
        continue;
      }

      for (final unavailability in person.unavailabilities) {
        if (!_dateRangeContains(unavailability.startDate, unavailability.endDate, day.date)) {
          continue;
        }

        final matchingSlotIds = [
          for (final slot in entry.value)
            if (_dayPartOverlapsBand(
              dayPart: unavailability.dayPart,
              windowStartMinute: unavailability.startMinute,
              windowEndMinute: unavailability.endMinute,
              bandStartMinute: slot.startMinute,
              bandEndMinute: slot.endMinute ?? slot.startMinute,
            ))
              slot.id,
        ];

        if (matchingSlotIds.isNotEmpty) {
          alerts.add(
            OcptSchedulePersonUnavailableAlert(
              dayId: day.id,
              personId: entry.key,
              unavailabilityId: unavailability.id,
              slotIds: matchingSlotIds,
            ),
          );
        }
      }
    }
  }
}

/// Rule 2: a person linked to two slots of one day whose own resolved bands overlap in wall-clock
/// time, strictly — a slot with no block at all (a null [OcptScheduleAlertSlot.endMinute]) never
/// takes part.
void _addPersonDoubleBookedAlerts(List<OcptScheduleAlert> alerts, List<OcptScheduleAlertDay> days) {
  for (final day in days) {
    final slots = day.slots;
    for (var i = 0; i < slots.length; i++) {
      final earlier = slots[i];
      final earlierEnd = earlier.endMinute;
      if (earlierEnd == null) {
        continue;
      }

      for (var j = i + 1; j < slots.length; j++) {
        final later = slots[j];
        final laterEnd = later.endMinute;
        if (laterEnd == null) {
          continue;
        }
        if (!(earlier.startMinute < laterEnd && later.startMinute < earlierEnd)) {
          continue;
        }

        for (final personId in earlier.personIds.intersection(later.personIds)) {
          alerts.add(
            OcptSchedulePersonDoubleBookedAlert(
              dayId: day.id,
              personId: personId,
              firstSlotId: earlier.id,
              secondSlotId: later.id,
            ),
          );
        }
      }
    }
  }
}

/// Rule 3: a slot whose location declares at least one window and none of them covers the slot's
/// own resolved band on the day's own date — a location declaring no window at all is skipped
/// entirely, raising nothing.
void _addLocationUncoveredAlerts(
  List<OcptScheduleAlert> alerts,
  List<OcptScheduleAlertDay> days,
  Map<String, List<OcptScheduleAlertLocationWindow>> locationWindowsByLocationId,
) {
  for (final day in days) {
    for (final slot in day.slots) {
      final locationId = slot.locationId;
      if (locationId == null) {
        continue;
      }

      final windows = locationWindowsByLocationId[locationId];
      if (windows == null || windows.isEmpty) {
        continue;
      }

      final slotEndMinute = slot.endMinute ?? slot.startMinute;
      final isCovered = windows.any(
        (window) =>
            _dateRangeContains(window.startDate, window.endDate, day.date) &&
            ocptWeekdayMaskCoversDate(window.weekdays, day.date) &&
            _dayPartCoversBand(
              dayPart: window.dayPart,
              windowStartMinute: window.startMinute,
              windowEndMinute: window.endMinute,
              bandStartMinute: slot.startMinute,
              bandEndMinute: slotEndMinute,
            ),
      );

      if (!isCovered) {
        alerts.add(
          OcptScheduleLocationUncoveredAlert(dayId: day.id, slotId: slot.id, locationId: locationId),
        );
      }
    }
  }
}

/// Rule 4: a role a placed shot calls for and no slot of that same day convokes, cast or not.
void _addRoleNotConvokedAlerts(List<OcptScheduleAlert> alerts, List<OcptScheduleAlertDay> days) {
  for (final day in days) {
    final convokedRoleIds = <String>{
      for (final slot in day.slots) ...slot.convokedRoleIds,
    };

    final seenRoleIds = <String>{};
    for (final calledRole in day.calledRoles) {
      if (!seenRoleIds.add(calledRole.roleId)) {
        continue; // Only the first shotId met for a role is kept — see the class doc comment.
      }
      if (!convokedRoleIds.contains(calledRole.roleId)) {
        alerts.add(
          OcptScheduleRoleNotConvokedAlert(
            dayId: day.id,
            roleId: calledRole.roleId,
            shotId: calledRole.shotId,
          ),
        );
      }
    }
  }
}

/// Rule 5: a role with no actor, restricted to a role the schedule actually uses somewhere — cast
/// on a slot of any day, or called for by a shot placed on any day.
void _addRoleUncastAlerts(
  List<OcptScheduleAlert> alerts,
  List<OcptScheduleAlertDay> days,
  List<OcptScheduleAlertRole> roles,
) {
  final usedRoleIds = <String>{};
  for (final day in days) {
    for (final slot in day.slots) {
      usedRoleIds.addAll(slot.convokedRoleIds);
    }
    for (final calledRole in day.calledRoles) {
      usedRoleIds.add(calledRole.roleId);
    }
  }

  for (final role in roles) {
    if (role.personId == null && usedRoleIds.contains(role.id)) {
      alerts.add(OcptScheduleRoleUncastAlert(roleId: role.id));
    }
  }
}

/// Rules 6 and 7: a straight pass-through of every day's own [OcptTimelineOverrun]s and
/// [OcptTimelineFixedEndMiss]es.
void _addTimelineAlerts(List<OcptScheduleAlert> alerts, List<OcptScheduleAlertDay> days) {
  for (final day in days) {
    for (final overrun in day.overruns) {
      alerts.add(
        OcptScheduleTimelineOverrunAlert(
          dayId: day.id,
          blockId: overrun.blockId,
          reachedMinute: overrun.reachedMinute,
          anchorMinute: overrun.anchorMinute,
        ),
      );
    }
    for (final miss in day.fixedEndMisses) {
      alerts.add(
        OcptScheduleFixedEndMissedAlert(
          dayId: day.id,
          slotId: miss.slotId,
          fixedEndMinute: miss.fixedEndMinute,
          actualEndMinute: miss.actualEndMinute,
        ),
      );
    }
  }
}

/// Every person's own arrival and departure on [day] — the earliest resolved slot start and the
/// latest resolved slot end over the slots of [day] they are linked to (`slot.personIds`), keyed
/// by person id; a person linked to no slot of [day] has no entry.
///
/// Shared by rules 8 and 9, which is the whole point of pulling it out: both ask "what is this
/// person's day", and a second, slightly different implementation of that question is exactly how
/// the two could come to disagree about it.
Map<String, ({int arrival, int departure})> _personDayBandsOf(OcptScheduleAlertDay day) {
  final arrivalByPersonId = <String, int>{};
  final departureByPersonId = <String, int>{};

  for (final slot in day.slots) {
    final slotEndMinute = slot.endMinute ?? slot.startMinute;
    for (final personId in slot.personIds) {
      final arrival = arrivalByPersonId[personId];
      if (arrival == null || slot.startMinute < arrival) {
        arrivalByPersonId[personId] = slot.startMinute;
      }
      final departure = departureByPersonId[personId];
      if (departure == null || slotEndMinute > departure) {
        departureByPersonId[personId] = slotEndMinute;
      }
    }
  }

  return {
    for (final personId in arrivalByPersonId.keys)
      personId: (arrival: arrivalByPersonId[personId]!, departure: departureByPersonId[personId]!),
  };
}

/// Rule 8: a person whose computed presence on a day — the latest slot end they are linked to minus
/// the earliest slot start — exceeds their own recorded maximum, when one was recorded at all.
void _addPresenceExceededAlerts(
  List<OcptScheduleAlert> alerts,
  List<OcptScheduleAlertDay> days,
  List<OcptScheduleAlertPerson> people,
) {
  final maxMinutesByPersonId = {
    for (final person in people)
      if (person.maxDailyPresenceMinutes != null) person.id: person.maxDailyPresenceMinutes!,
  };
  if (maxMinutesByPersonId.isEmpty) {
    return;
  }

  for (final day in days) {
    final bandsByPersonId = _personDayBandsOf(day);

    for (final entry in maxMinutesByPersonId.entries) {
      final band = bandsByPersonId[entry.key];
      if (band == null) {
        continue; // Not convoked on this day at all.
      }

      final presenceMinutes = band.departure - band.arrival;
      if (presenceMinutes > entry.value) {
        alerts.add(
          OcptSchedulePresenceExceededAlert(
            dayId: day.id,
            personId: entry.key,
            presenceMinutes: presenceMinutes,
            maxDailyPresenceMinutes: entry.value,
          ),
        );
      }
    }
  }
}

/// Rule 9: a person's own departure on one day and their arrival on the **next day they are
/// actually convoked on** (never merely the next calendar date) are closer together than
/// [minimumRestMinutes] — silent outright when nobody has recorded one (this function's own doc
/// comment, and [OcptScheduleRestTimeAlert]'s).
///
/// [days] is walked in **date order**, not in the order it arrived in: this rule is about calendar
/// dates rather than about the order the caller happened to hand its days over in, so it sorts them
/// itself. The sort is a **stable** one over `(date, original index)` rather than a
/// bare `List.sort` (not guaranteed stable by the language), so two days sharing one date are still
/// compared in the caller's own order, both anchored on the same midnight, exactly as the class doc
/// comment promises.
void _addRestTimeAlerts(
  List<OcptScheduleAlert> alerts,
  List<OcptScheduleAlertDay> days,
  List<OcptScheduleAlertPerson> people,
  int? minimumRestMinutes,
) {
  if (minimumRestMinutes == null) {
    return;
  }

  final indexedDays =
      [for (var index = 0; index < days.length; index++) (index: index, day: days[index])]
        ..sort((left, right) {
          final byDate = left.day.date.compareTo(right.day.date);
          return byDate != 0 ? byDate : left.index.compareTo(right.index);
        });
  final sortedDays = [for (final entry in indexedDays) entry.day];

  final bandsByDayId = {for (final day in sortedDays) day.id: _personDayBandsOf(day)};

  for (final person in people) {
    OcptScheduleAlertDay? previousDay;
    int? previousDeparture;

    for (final day in sortedDays) {
      final band = bandsByDayId[day.id]![person.id];
      if (band == null) {
        continue; // Not convoked this day — the walk skips straight to the next one they are.
      }

      if (previousDay != null && previousDeparture != null) {
        final restMinutes =
            _wholeDayDifference(previousDay.date, day.date) * 1440 +
            band.arrival -
            previousDeparture;
        if (restMinutes < minimumRestMinutes) {
          alerts.add(
            OcptScheduleRestTimeAlert(
              dayId: day.id,
              personId: person.id,
              previousDayId: previousDay.id,
              restMinutes: restMinutes,
              minimumRestMinutes: minimumRestMinutes,
            ),
          );
        }
      }

      previousDay = day;
      previousDeparture = band.departure;
    }
  }
}

/// The whole number of calendar days between [start] and [end] (positive when [end] is the later
/// date), computed on [DateTime.utc]-anchored dates rather than local-time ones: a local `DateTime`
/// difference taken across a daylight-saving change can read as 23 or 25 hours for what is
/// genuinely a one-day gap, while a UTC one never observes a change that never happened to it.
int _wholeDayDifference(DateTime start, DateTime end) {
  final startUtc = DateTime.utc(start.year, start.month, start.day);
  final endUtc = DateTime.utc(end.year, end.month, end.day);
  return endUtc.difference(startUtc).inDays;
}

/// Rule 10: a slot booked at a location that declares at least one dated permit window, none of
/// which covers the day's own date. A location with no window at all — the empty list, or a list
/// whose every entry carries neither date — raises nothing: the identical argument rule 3 already
/// makes for a location declaring no availability window.
void _addPermitNotValidAlerts(
  List<OcptScheduleAlert> alerts,
  List<OcptScheduleAlertDay> days,
  Map<String, List<OcptSchedulePermitWindow>> permitWindowsByLocationId,
) {
  for (final day in days) {
    for (final slot in day.slots) {
      final locationId = slot.locationId;
      if (locationId == null) {
        continue;
      }

      final windows = [
        for (final window
            in permitWindowsByLocationId[locationId] ?? const <OcptSchedulePermitWindow>[])
          if (window.validFrom != null || window.validUntil != null) window,
      ];
      if (windows.isEmpty) {
        continue;
      }

      final isCovered = windows.any((window) => _permitWindowCoversDate(window, day.date));
      if (!isCovered) {
        alerts.add(
          OcptSchedulePermitNotValidAlert(dayId: day.id, slotId: slot.id, locationId: locationId),
        );
      }
    }
  }
}

/// Whether [window] covers calendar [date] — a one-sided window (only [OcptSchedulePermitWindow
/// .validFrom] or only [OcptSchedulePermitWindow.validUntil] recorded) is open on the missing side,
/// a different statement from a window recording neither, which [_addPermitNotValidAlerts] already
/// filters out before this is ever called.
bool _permitWindowCoversDate(OcptSchedulePermitWindow window, DateTime date) {
  final day = _dateOnly(date);
  final validFrom = window.validFrom;
  final validUntil = window.validUntil;
  return (validFrom == null || !day.isBefore(_dateOnly(validFrom))) &&
      (validUntil == null || !day.isAfter(_dateOnly(validUntil)));
}

/// Whether [date] falls within [startDate]–[endDate], inclusive, comparing calendar dates alone —
/// whatever time-of-day component a stored `DateTime` carries is ignored.
bool _dateRangeContains(DateTime startDate, DateTime endDate, DateTime date) {
  final day = _dateOnly(date);
  return !day.isBefore(_dateOnly(startDate)) && !day.isAfter(_dateOnly(endDate));
}

/// [date] with its time-of-day component stripped.
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Whether a window of [dayPart] — [windowStartMinute]/[windowEndMinute] only meaningful when
/// [dayPart] is [OcptDayPartSlot.custom] — **overlaps** the half-open band
/// `[bandStartMinute, bandEndMinute)`. What rule 1 asks: is any part of this slot inside the window.
bool _dayPartOverlapsBand({
  required OcptDayPartSlot dayPart,
  required int? windowStartMinute,
  required int? windowEndMinute,
  required int bandStartMinute,
  required int bandEndMinute,
}) {
  switch (dayPart) {
    case OcptDayPartSlot.fullDay:
      return true;
    case OcptDayPartSlot.morning:
      return bandStartMinute < _dayPartSplitMinute && bandEndMinute > 0;
    case OcptDayPartSlot.afternoon:
      return bandEndMinute > _dayPartSplitMinute;
    case OcptDayPartSlot.custom:
      final start = windowStartMinute ?? 0;
      final end = windowEndMinute ?? start;
      return bandStartMinute < end && start < bandEndMinute;
  }
}

/// Whether a window of [dayPart] **contains the whole** of the half-open band
/// `[bandStartMinute, bandEndMinute)` — what rule 3 asks: is this slot's entire band inside the
/// window, not merely touching it. Deliberately a different test from [_dayPartOverlapsBand]: rule
/// 1 asks whether any of the slot conflicts, rule 3 asks whether the whole of it is covered.
bool _dayPartCoversBand({
  required OcptDayPartSlot dayPart,
  required int? windowStartMinute,
  required int? windowEndMinute,
  required int bandStartMinute,
  required int bandEndMinute,
}) {
  switch (dayPart) {
    case OcptDayPartSlot.fullDay:
      return true;
    case OcptDayPartSlot.morning:
      return bandEndMinute <= _dayPartSplitMinute;
    case OcptDayPartSlot.afternoon:
      return bandStartMinute >= _dayPartSplitMinute;
    case OcptDayPartSlot.custom:
      final start = windowStartMinute ?? 0;
      final end = windowEndMinute ?? start;
      return start <= bandStartMinute && bandEndMinute <= end;
  }
}
