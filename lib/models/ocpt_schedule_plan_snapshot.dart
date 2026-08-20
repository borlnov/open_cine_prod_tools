// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_effect.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The whole schedule read, joined into the day-level facts every reader of the schedule mode is
/// understood through — a slot's own resolved hours, a day's whole call, its sun times, its first
/// location.
///
/// This is the single place `OcptScheduleState` and the schedule's own coming PDF exports (call
/// sheets, shooting plan) both reach for those joins from: the manager layer the exports run in
/// holds no bloc state, but needs exactly the same answers the day view already reads — the hour a
/// slot starts at, chief among them — and a second implementation of that join is how a printed
/// call sheet and the day view would come to disagree about it. `ocpt_shooting_day_timeline.dart`,
/// `ocpt_shooting_convocations.dart` and `ocpt_sun_times.dart` know nothing of `shots`, `roles` or
/// drift at all; joining their pure inputs out of the stored rows is this class's whole job.
///
/// A **shooting day belongs to no episode** (`docs/adr/0019`): a day regularly covers two episodes
/// at one location, which is the point of shooting a series out of order and is what the shared
/// schedule buys. [shotLists], [headingBySceneId], [sceneNumberBySceneId] and [sceneSpanBySceneId]
/// are therefore the **project's**, not one screenplay's — every episode's own shot list joined
/// into one set of maps, so a day playing two episodes reads one call sheet rather than one it
/// would have to ask twice.
///
/// Built the same way `OcptBreakdownSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. Unlike a per-read state getter, [locationById]/[setById]/
/// [roleById]/[personById]/[episodeById]/[shotsById] are built **once**, in
/// [OcptSchedulePlanSnapshot.build], and stored as unmodifiable maps — a caller walking a whole
/// shoot's worth of days must not rebuild the address book once per day.
///
/// [alerts] is the same idea taken one step further: it is a whole-shoot walk (`lib/utils/
/// ocpt_schedule_alerts.dart`), so it is a `late final` field computed once, on first read, rather
/// than a getter recomputed on every one — see its own doc comment for why that field is also what
/// keeps this class from being `const` any more.
class OcptSchedulePlanSnapshot extends Equatable {
  /// The whole schedule read: days, slots and blocks.
  final OcptScheduleSnapshot schedule;

  /// Every live episode's own shot list, one entry per episode, in
  /// `OcptScreenplayService.loadEpisodes`' own order (which is [episodes]' own order too) — empty
  /// for a project whose shot lists have not been read yet, which is what a null used to mean before
  /// a schedule could cover more than one episode. What a placed shot's own duration and characters
  /// are resolved from, across every episode.
  final List<OcptShotListSnapshot> shotLists;

  /// The project's live episodes, in the same order as [shotLists] — what [episodeById] is derived
  /// from, and what names a run when the sides are composed one per episode.
  final List<OcptEpisode> episodes;

  /// The project's whole location catalogue (with their sets), as passed to
  /// [OcptSchedulePlanSnapshot.build].
  final List<OcptLocation> locations;

  /// The project's whole cast, as passed to [OcptSchedulePlanSnapshot.build].
  final List<OcptRole> roles;

  /// The project's whole address book, as passed to [OcptSchedulePlanSnapshot.build].
  final List<OcptPerson> people;

  /// The project's whole elements catalogue, as passed to [OcptSchedulePlanSnapshot.build] — what a
  /// named call sheet's own "to bring" section ([elementsToBringOnDay]) is read off.
  final List<OcptElement> elements;

  /// Every live candidacy of the project — who was seen for which part — in no particular order,
  /// as passed to [OcptSchedulePlanSnapshot.build]. What a `shooting_slot_candidates` link and an
  /// `audition` block are both resolved to a name and a part through ([roleCandidateById]).
  ///
  /// Empty on a project that has auditioned nobody, which is most of them: the schedule reads this
  /// catalogue for the same reason it reads the elements one — one surface needs it — and a
  /// project with no casting simply joins nothing.
  final List<OcptRoleCandidate> roleCandidates;

  /// `project_info.minimumRestMinutes` verbatim, as passed to [OcptSchedulePlanSnapshot.build] —
  /// null while nobody has recorded one, which [alerts]' own rest-time rule never fires on. Every
  /// call site states it explicitly (a required parameter, not a default) so a forgotten one can
  /// never silently disable that rule.
  final int? minimumRestMinutes;

  /// The whole location catalogue, keyed by id.
  final Map<String, OcptLocation> locationById;

  /// Every set of every location of [locations], keyed by id.
  final Map<String, OcptSet> setById;

  /// The whole cast, keyed by id.
  final Map<String, OcptRole> roleById;

  /// The whole address book, keyed by id.
  final Map<String, OcptPerson> personById;

  /// [roleCandidates], keyed by id — what a candidate's convocation and an `audition` block resolve
  /// their `roleCandidateId` through. A row this map no longer holds reads as nothing at all: the
  /// candidacy has been removed since, and no cascade drops the schedule rows naming it (see
  /// `OcptShootingSlotCandidatesTable`).
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// [episodes], keyed by id — the same derivation [locationById]/[setById]/[roleById]/[personById]
  /// already make, for the same reason.
  final Map<String, OcptEpisode> episodeById;

  /// Every shot of every entry of [shotLists], keyed by id — a plain union, since a shot's own id is
  /// a UUID and cannot collide between two episodes. Derived once, in
  /// [OcptSchedulePlanSnapshot.build], so [shotById] stays O(1): [alerts]' own whole-shoot walk
  /// calls it once per placed block over the whole shoot, which a per-call walk of [shotLists] would
  /// pay for on every one of them.
  final Map<String, OcptShot> shotsById;

  /// Class constructor. Prefer [OcptSchedulePlanSnapshot.build], which derives [locationById],
  /// [setById], [roleById], [personById], [episodeById] and [shotsById] rather than asking a caller
  /// to keep them in step by hand.
  ///
  /// Not `const`, unlike most models in this app: [alerts] is a `late final` field, which a const
  /// constructor cannot carry. Nothing ever built this snapshot as a constant.
  OcptSchedulePlanSnapshot({
    required this.schedule,
    required this.shotLists,
    required this.episodes,
    required this.locations,
    required this.roles,
    required this.people,
    required this.elements,
    required this.roleCandidates,
    required this.minimumRestMinutes,
    required this.locationById,
    required this.setById,
    required this.roleById,
    required this.personById,
    required this.roleCandidateById,
    required this.episodeById,
    required this.shotsById,
  });

  /// Builds an [OcptSchedulePlanSnapshot] from [schedule], every live episode's own [shotLists], the
  /// four catalogues and [minimumRestMinutes], deriving [locationById]/[setById]/[roleById]/
  /// [personById]/[roleCandidateById]/[episodeById]/[shotsById] from them once.
  ///
  /// [roleCandidates] is the one parameter carrying a default, and deliberately: every other
  /// catalogue here is read by something the mode draws on every day of every project, while a
  /// candidacy is only ever resolved on a day that sees people for a part. A caller with none to
  /// hand — every export test over an ordinary shoot — passes nothing and joins nothing, and a
  /// forgotten one costs a candidate's name on a casting day rather than silently disabling a rule.
  ///
  /// [episodes] is a **required** parameter with no default, exactly as [minimumRestMinutes] is and
  /// for the same reason: an empty list is a truthful state (a project whose episodes have not been
  /// read yet), so a default would let a caller reach it by forgetting rather than by meaning it —
  /// and a forgotten one silently names no episode where a booklet of sides or a banded list is
  /// supposed to name one. A single-episode project passes its single episode; a test exercising a
  /// join that names none passes `const []` and says so by writing it.
  factory OcptSchedulePlanSnapshot.build({
    required OcptScheduleSnapshot schedule,
    required List<OcptShotListSnapshot> shotLists,
    required List<OcptEpisode> episodes,
    required List<OcptLocation> locations,
    required List<OcptRole> roles,
    required List<OcptPerson> people,
    required List<OcptElement> elements,
    required int? minimumRestMinutes,
    List<OcptRoleCandidate> roleCandidates = const [],
  }) => OcptSchedulePlanSnapshot(
    schedule: schedule,
    shotLists: shotLists,
    episodes: episodes,
    locations: locations,
    roles: roles,
    people: people,
    elements: elements,
    roleCandidates: roleCandidates,
    minimumRestMinutes: minimumRestMinutes,
    locationById: Map.unmodifiable({for (final location in locations) location.id: location}),
    setById: Map.unmodifiable({
      for (final location in locations)
        for (final set in location.sets) set.id: set,
    }),
    roleById: Map.unmodifiable({for (final role in roles) role.id: role}),
    personById: Map.unmodifiable({for (final person in people) person.id: person}),
    roleCandidateById: Map.unmodifiable({
      for (final candidate in roleCandidates) candidate.id: candidate,
    }),
    episodeById: Map.unmodifiable({for (final episode in episodes) episode.id: episode}),
    shotsById: Map.unmodifiable({
      for (final shotList in shotLists) ...shotList.shotsById,
    }),
  );

  /// The shot [shotId] names, or null while it hasn't been read yet (or it has since been deleted).
  /// Reads the merged [shotsById] rather than walking [shotLists] itself — see that field's own doc
  /// comment for why.
  OcptShot? shotById(String shotId) => shotsById[shotId];

  /// [dayId]'s own computed timelines (ADR 0015, as amended), one chain per live slot, joined
  /// into a single [OcptShootingDayTimelines] — or null while the day has no live slot to chain at
  /// all.
  ///
  /// Computed here rather than stored: reading it costs nothing beyond a handful of list lookups
  /// already held in memory, and storing it would be one more thing every write to that day's
  /// blocks would have to remember to invalidate.
  OcptShootingDayTimelines? timelinesOfDay(String dayId) {
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (slots.isEmpty) {
      return null;
    }

    final blocks = schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[];
    final blocksBySlotId = <String, List<OcptShootingDayBlock>>{};
    for (final block in blocks) {
      (blocksBySlotId[block.slotId] ??= <OcptShootingDayBlock>[]).add(block);
    }

    final timelineSlots = [
      for (final slot in slots)
        OcptShootingTimelineSlot(
          id: slot.id,
          anchorEdge: slot.anchorEdge,
          anchorMinute: slot.anchorMinute,
          anchorSlotId: slot.anchorSlotId,
          blocks: [
            for (final block in blocksBySlotId[slot.id] ?? const <OcptShootingDayBlock>[])
              OcptShootingTimelineBlock(
                id: block.id,
                durationMinutes: block.durationMinutes,
                fallbackDurationMinutes: block.kind == OcptShootingBlockKind.shot && block.shotId != null
                    ? _durationMinutesOfShot(block.shotId!)
                    : null,
                anchorMinute: block.anchorMinute,
              ),
          ],
        ),
    ];

    return ocptComputeShootingDayTimelines(
      slots: timelineSlots,
      defaultDurationMinutes: ocptDefaultBlockDurationMinutes,
    );
  }

  /// Day [dayId]'s own whole call (ADR 0018): one `OcptDayConvocation` per person, per uncast role,
  /// per guest and per candidate linked to any of its live slots, empty while [dayId] names no day
  /// with a live slot at all.
  ///
  /// Built by [ocptComputeDayConvocations] over one [OcptConvocationSlot] per live slot
  /// ([_convocationSlotOf]) — that pure function knows nothing of `shots`, `roles` or the timeline,
  /// so joining a slot's already-chained blocks ([timelinesOfDay]) onto its own crew and cast rows,
  /// and resolving a cast role's own actor through [roleById], is this snapshot's job alone.
  List<OcptDayConvocation> convocationsOfDay(String dayId) {
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (slots.isEmpty) {
      return const [];
    }

    final timelines = timelinesOfDay(dayId);
    final blocksById = {
      for (final block in schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[])
        block.id: block,
    };

    return ocptComputeDayConvocations(
      slots: [
        // Every live slot of the day was handed to [timelinesOfDay] just above, so each has its own
        // entry back: the `!` is that round trip, not an assumption about the data.
        for (final slot in slots)
          _convocationSlotOf(slot, timelines!.bySlotId[slot.id]!, blocksById),
      ],
    );
  }

  /// Builds [slot]'s own [OcptConvocationSlot]: [OcptConvocationSlot.shootingStartMinute]/
  /// [OcptConvocationSlot.shootingEndMinute] are the minimum start and the maximum end, over
  /// [timeline]'s own entries whose [blocksById] row is a [OcptShootingBlockKind.shot] or a
  /// shooting block (`OcptShootingBlockKind.isShootingTime` — a shot, a hold, an audition or a
  /// rehearsal) — a minimum and a maximum rather than "the first and last entry",
  /// since a pinned anchor can put a block earlier than the one before it in chain order —
  /// [OcptConvocationSlot.personIds]/[OcptConvocationSlot.uncastRoleIds] come from [slot]'s own live
  /// crew and cast rows, a cast role's own actor read through [roleById]'s own `personId`,
  /// [OcptConvocationSlot.guestPersonIds]/[OcptConvocationSlot.guestFreeNames] come straight off
  /// [slot]'s own live [OcptShootingSlot.guests] — a guest's `personId`/`freeName` already being the
  /// discriminator [ocptComputeDayConvocations] itself groups on, there is no join left to do here —
  /// and [OcptConvocationSlot.roleCandidateIds] comes off its own live
  /// [OcptShootingSlot.candidates], **filtered through [roleCandidateById]**: a link onto a
  /// candidacy that has since been removed convokes nobody, and dropping it here is what keeps a
  /// stale row from drawing a nameless card.
  ///
  /// [OcptConvocationSlot.startMinute] is [timeline]'s own **resolved** start, never a stored
  /// column: a slot pinned by its end starts wherever its blocks put it, and a convocation is what
  /// that lands on.
  OcptConvocationSlot _convocationSlotOf(
    OcptShootingSlot slot,
    OcptShootingSlotTimeline timeline,
    Map<String, OcptShootingDayBlock> blocksById,
  ) {
    int? shootingStartMinute;
    int? shootingEndMinute;
    for (final entry in timeline.entries) {
      final kind = blocksById[entry.blockId]?.kind;
      if (kind == null || !kind.isShootingTime) {
        continue;
      }
      if (shootingStartMinute == null || entry.startMinute < shootingStartMinute) {
        shootingStartMinute = entry.startMinute;
      }
      if (shootingEndMinute == null || entry.endMinute > shootingEndMinute) {
        shootingEndMinute = entry.endMinute;
      }
    }

    final personIds = <String>{for (final member in slot.crew) member.personId};
    final uncastRoleIds = <String>{};
    for (final member in slot.cast) {
      final actorId = roleById[member.roleId]?.personId;
      if (actorId != null) {
        personIds.add(actorId);
      } else {
        uncastRoleIds.add(member.roleId);
      }
    }

    final guestPersonIds = <String>{};
    final guestFreeNames = <String>{};
    for (final guest in slot.guests) {
      final guestPersonId = guest.personId;
      if (guestPersonId != null) {
        guestPersonIds.add(guestPersonId);
      } else if (guest.freeName.isNotEmpty) {
        guestFreeNames.add(guest.freeName);
      }
    }

    final roleCandidateIds = <String>{
      for (final candidate in slot.candidates)
        if (roleCandidateById.containsKey(candidate.roleCandidateId)) candidate.roleCandidateId,
    };

    return OcptConvocationSlot(
      id: slot.id,
      startMinute: timeline.startMinute,
      endMinute: timeline.endMinute,
      shootingStartMinute: shootingStartMinute,
      shootingEndMinute: shootingEndMinute,
      personIds: personIds,
      uncastRoleIds: uncastRoleIds,
      guestPersonIds: guestPersonIds,
      guestFreeNames: guestFreeNames,
      roleCandidateIds: roleCandidateIds,
    );
  }

  /// Day [dayId]'s own earliest arrival — the minimum **resolved** start over its live slots
  /// ([OcptShootingDayTimelines.dayStartMinute]) — or null while it has no live slot at all.
  ///
  /// Reads off the slots alone, not off who is convoked (ADR 0018): nothing pulls an arrival ahead
  /// of its own slot's start any more, so the day's earliest slot start already is its earliest
  /// arrival, with no convocation to compute for it. It reads the **resolved** start rather than a
  /// stored column, an end-anchored slot's own start being a fact about its blocks (ADR 0015,
  /// amended a second time).
  int? dayArrivalMinute(String dayId) => timelinesOfDay(dayId)?.dayStartMinute;

  /// [shotId]'s own `estimatedDurationMs`, converted to minutes, or null while it has none yet (or
  /// the shot isn't loaded).
  int? _durationMinutesOfShot(String shotId) {
    final estimatedDurationMs = shotById(shotId)?.estimatedDurationMs;
    return estimatedDurationMs == null ? null : (estimatedDurationMs / 60000).round();
  }

  /// [dayId]'s own computed sun and twilight times (ADR 0016), or null while its first live slot
  /// has no location, or that location has no coordinates pinned yet.
  OcptSunTimes? sunTimesOfDay(String dayId) {
    final day = schedule.daysById[dayId];
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (day == null || slots.isEmpty) {
      return null;
    }

    final location = locationById[slots.first.locationId];
    final latitude = location?.latitude;
    final longitude = location?.longitude;
    if (latitude == null || longitude == null) {
      return null;
    }

    return ocptSunTimesOf(date: day.date, latitudeDegrees: latitude, longitudeDegrees: longitude);
  }

  /// [dayId]'s own first live slot's location, or null while it has none — what a day's own tint
  /// (`ocptScheduleDayLocationTint`) and its inspector's own "Locations" line are read off.
  OcptLocation? firstLocationOfDay(String dayId) {
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    return slots.isEmpty ? null : locationById[slots.first.locationId];
  }

  /// The scene ids of every [OcptShootingBlockKind.shot] block placed on [dayId], deduplicated — the
  /// scenes the day actually plays, which is what [elementsToBringOnDay] joins an element's own
  /// [OcptElement.sceneLinks] against. A block naming no shot, or a shot with no scene (an orphaned
  /// heading), contributes nothing: there is no scene id to test an element's own link against.
  ///
  /// Computed on every read rather than memoised: unlike [timelinesOfDay] or [headingBySceneId],
  /// which the three agendas call once per day cell across a whole month grid, this is read at most
  /// once per named call sheet [elementsToBringOnDay] renders — a walk over one day's own blocks,
  /// no costlier than [firstLocationOfDay]'s own per-read scan just above.
  Set<String> sceneIdsOfDay(String dayId) => {
    for (final block in schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[])
      if (block.kind == OcptShootingBlockKind.shot && block.shotId != null)
        if (shotById(block.shotId!)?.sceneId case final sceneId?) sceneId,
  };

  /// Every role [dayId] convokes, across all of its live slots — the union of their own
  /// `shooting_slot_cast` rows, which is what the *Day Out of Days* reads a cell from.
  ///
  /// Names **roles**, never actors, and deliberately so: a *Day Out of Days* is negotiated per part,
  /// an uncast role is exactly as scheduled as a cast one, and recasting a part must not redraw the
  /// document. It is the same set [_alertSlotOf] builds per slot for the position and convocation
  /// rules, joined here across the whole day rather than per slot — a role convoked on the morning
  /// unit and again in the evening is on that day once.
  ///
  /// Computed on every read rather than memoised, exactly as [sceneIdsOfDay] is and for the same
  /// reason: it is a walk over one day's own slots, read once per printed day.
  Set<String> convokedRoleIdsOfDay(String dayId) => {
    for (final slot in schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[])
      for (final member in slot.cast) member.roleId,
  };

  /// The live elements [personId] is due to bring to [dayId]: every [elements] row whose
  /// [OcptElement.broughtByPersonId] is [personId] **and** at least one of whose
  /// [OcptElement.sceneLinks] names a scene [sceneIdsOfDay] says the day actually plays — the join a
  /// named call sheet's own "to bring" section reads. Sorted by [OcptElement.category] (the enum's
  /// own declaration order, `prop` before `costume` before `other`) then by [OcptElement.name], the
  /// grouping a printed list reads the way the resources mode's own elements board already groups.
  ///
  /// Both conditions are deliberate, and neither alone is enough: an element [personId] brings but
  /// that no scene of [dayId] needs is left off — a call sheet says what to bring **today**, not
  /// everything that production ever assigned them — and an element a scene of [dayId] needs but
  /// somebody else brings is exactly as absent, being nobody's own instruction to pack it. Nothing
  /// here is guessed at: the two columns already say who brings what and where it is needed, and
  /// this is their join, not a new fact invented for the call sheet.
  List<OcptElement> elementsToBringOnDay({required String dayId, required String personId}) {
    final sceneIds = sceneIdsOfDay(dayId);
    final toBring = [
      for (final element in elements)
        if (element.broughtByPersonId == personId)
          if (element.sceneLinks.any((link) => sceneIds.contains(link.sceneId))) element,
    ];

    toBring.sort((a, b) {
      final categoryComparison = a.category.index.compareTo(b.category.index);
      return categoryComparison != 0 ? categoryComparison : a.name.compareTo(b.name);
    });
    return toBring;
  }

  /// A map from every real scene's id to its own heading, built once across every entry of
  /// [shotLists] — read by the two schedule PDF exports for a [OcptShootingBlockKind.hold] block's
  /// own caption and the call sheet's own `EFFET` column (`ocptScheduleHeadingBySceneId`, now a thin
  /// wrapper over this field), and by [effectCategoryOfDay] below for the agenda's own "Colour by
  /// effect" tint — the very same join, so a printed call sheet and the agenda can never read a
  /// heading differently.
  ///
  /// This is the **project's** map now, not one screenplay's (`docs/adr/0019`): a scene id is a
  /// UUID, so merging every episode's own shot list into one map can never collide two scenes onto
  /// one entry.
  late final Map<String, String> headingBySceneId = {
    for (final shotList in shotLists)
      for (final sequence in shotList.sequences)
        if (sequence is OcptSceneShotSequence) sequence.sceneId: sequence.heading,
  };

  /// A map from every real scene's id to its own display scene number, built once across every entry
  /// of [shotLists], alongside [headingBySceneId] and the very same way — read by the one-line
  /// schedule's own `SEQ` column for every scene a hold or a shot block names, so a printed sequence
  /// number can never disagree with the shot list's own reading of it. A shot naming no scene at all
  /// (an orphaned one) has no entry here to read, which is why that column falls back to the shot's
  /// own `ocptShotSceneNumberOf` rather than this map for such a shot.
  ///
  /// This is the **project's** map now, not one screenplay's, and it is safe for the same reason
  /// [headingBySceneId] is: a scene id is a UUID, so no two episodes' scenes ever collide onto one
  /// entry. Each episode's own [OcptSceneShotSequence.displaySceneNumber] already carries its own
  /// `<episode>.<scene>` prefix, resolved by `OcptShotListService.loadShotList`'s own
  /// `episodeNumber` at the moment that episode's shot list was read — so this map is where a
  /// printed sequence code becomes unambiguous across a day that plays two episodes: `1.3` and
  /// `2.4` read here exactly as their own shot lists built them, never renumbered against one
  /// another.
  late final Map<String, String> sceneNumberBySceneId = {
    for (final shotList in shotLists)
      for (final sequence in shotList.sequences)
        if (sequence is OcptSceneShotSequence) sequence.sceneId: sequence.displaySceneNumber,
  };

  /// A map from every real scene's id to the span, `[charStart, charEnd)`, of its own screenplay's
  /// Fountain source that scene was indexed at — copied off the `scenes` row through the shot list
  /// snapshot, exactly as [OcptSceneShotSequence.charStart]/`.charEnd` already carry it for the
  /// scenario coverage editor. Built once across every entry of [shotLists], alongside
  /// [headingBySceneId] and [sceneNumberBySceneId] and for the same reason: a caller walking a whole
  /// shoot's worth of days must not rebuild the join per day, and a scene id being a UUID keeps the
  /// merge across episodes as safe as theirs.
  ///
  /// This is what the sides export slices a day's own scenes out of each episode's own composed
  /// script by: a side is the screenplay's real page, reprinted rather than re-typeset, and the span
  /// is the address of the source text that page has to be sliced from — [screenplayIdBySceneId] is
  /// what says which episode's own text to slice it out of.
  late final Map<String, ({int charStart, int charEnd})> sceneSpanBySceneId = {
    for (final shotList in shotLists)
      for (final sequence in shotList.sequences)
        if (sequence is OcptSceneShotSequence)
          sequence.sceneId: (charStart: sequence.charStart, charEnd: sequence.charEnd),
  };

  /// Every real scene's id onto the screenplay (episode) it belongs to, built once across every
  /// entry of [shotLists] — what the sides export slices a day's own scenes per episode by (a day
  /// regularly plays two of them), and what the two grouped surfaces (the left dock's own "shots
  /// still to place" list and the shot picker dialog) band their own rows by.
  late final Map<String, String> screenplayIdBySceneId = {
    for (final shotList in shotLists)
      for (final sequence in shotList.sequences)
        if (sequence is OcptSceneShotSequence) sequence.sceneId: shotList.screenplayId,
  };

  /// Every real scene's own [OcptSceneShotSequence], keyed by scene id, merged across every entry of
  /// [shotLists] — built once so `OcptShootingPlanGrids` stops reaching into one screenplay's own
  /// `shotList!.sequences` itself: it is the same join that class used to build inline, made once
  /// per snapshot rather than once per grid.
  late final Map<String, OcptSceneShotSequence> sceneSequenceBySceneId = {
    for (final shotList in shotLists)
      for (final sequence in shotList.sequences)
        if (sequence is OcptSceneShotSequence) sequence.sceneId: sequence,
  };

  /// [dayId]'s own effect reading (`ocptSceneEffectCategoryOf`): the EFFET classification of every
  /// [OcptShootingBlockKind.shot] block's own scene heading placed on it, one of the four categories
  /// when they agree, [OcptSceneEffectCategory.mixed] when they don't, or null when nothing placed
  /// on [dayId] classifies at all. What `OcptScheduleAgendaColorMode.effect` tints a day with,
  /// mirroring [firstLocationOfDay] for `OcptScheduleAgendaColorMode.location`.
  ///
  /// A [OcptShootingBlockKind.hold] block is deliberately left out, unlike [_calledRolesOfDay]'s own
  /// restriction to shot blocks for a different reason here: it may name a sequence not yet
  /// shot-listed at all, and a day is tinted by what is actually being **shot** on it, not by what
  /// is merely blocked out for later.
  OcptSceneEffectCategory? effectCategoryOfDay(String dayId) {
    final blocks = schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[];

    return ocptSceneEffectCategoryOf([
      for (final block in blocks)
        if (block.kind == OcptShootingBlockKind.shot && block.shotId != null)
          if (shotById(block.shotId!)?.sceneId case final sceneId?) headingBySceneId[sceneId],
    ]);
  }

  /// Every day's own working person ids — everyone convoked on it as a human, cast or crew — built
  /// once, alongside [alerts], out of [convocationsOfDay] over every live day: the presence grid's
  /// own computed `working` reading ([presenceCellOf]) must agree with the `Convocations` panel
  /// about who is convoked, so it reads off that very computation rather than a second join over
  /// `shooting_slot_crew`/`shooting_slot_cast`.
  ///
  /// Reads [OcptDayConvocation.personId] alone, never [OcptDayConvocation.guestPersonId]: a guest is
  /// never `working` here, being on set to watch a shoot is not being convoked to work, and
  /// [OcptDayConvocation.personId] is already null on every guest convocation
  /// ([OcptDayConvocation.isGuest]) by construction — there is nothing to filter out on purpose.
  late final Map<String, Set<String>> _workingPersonIdsByDayId = {
    for (final day in schedule.days)
      day.id: {
        for (final convocation in convocationsOfDay(day.id))
          if (convocation.personId != null) convocation.personId!,
      },
  };

  /// The presence grid's own effective cell for [personId] on [dayId] — entirely computed, in
  /// order: [OcptPresenceCode.working] when [personId] is convoked on [dayId]
  /// ([_workingPersonIdsByDayId]), [OcptPresenceCode.unavailable] when they are not convoked but one
  /// of their own [OcptPerson.unavailabilities] covers [dayId]'s own calendar date, or null when
  /// neither applies — absence of information, never a claim. There is no override left to consult
  /// first any more: schema v17 drops `shooting_presences` (`OcptProjectDatabase`'s own doc
  /// comment), the grid having never needed to restate what the resources mode already recorded.
  ///
  /// The unavailability check here compares calendar dates alone, not the day-part overlap rule 1 of
  /// `lib/utils/ocpt_schedule_alerts.dart` refines against a slot's own band: a person read as
  /// [OcptPresenceCode.unavailable] here is, by construction, convoked on **no** slot of [dayId] at
  /// all (the `working` branch above already claimed that case), so there is no band left to refine
  /// against — the two checks never fire on the same person on the same day, and can therefore never
  /// disagree.
  OcptPresenceCode? presenceCellOf({required String dayId, required String personId}) {
    if (_workingPersonIdsByDayId[dayId]?.contains(personId) ?? false) {
      return OcptPresenceCode.working;
    }

    final day = schedule.daysById[dayId];
    final person = personById[personId];
    if (day != null && person != null && _unavailabilityCoversDate(person, day.date)) {
      return OcptPresenceCode.unavailable;
    }

    return null;
  }

  /// Whether any of [person]'s own recorded unavailabilities covers calendar [date] — comparing
  /// dates alone, own time-of-day component dropped, mirroring
  /// `lib/utils/ocpt_schedule_alerts.dart`'s own private `_dateRangeContains` (duplicated rather
  /// than shared: that file's own doc comment keeps it free of anything beyond the eleven alert
  /// rules, and this one-line check creates no risk of disagreement — see [presenceCellOf]'s own
  /// doc comment for why the two never fire on the same case).
  bool _unavailabilityCoversDate(OcptPerson person, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    for (final unavailability in person.unavailabilities) {
      final start = DateTime(
        unavailability.startDate.year,
        unavailability.startDate.month,
        unavailability.startDate.day,
      );
      final end = DateTime(
        unavailability.endDate.year,
        unavailability.endDate.month,
        unavailability.endDate.day,
      );
      if (!day.isBefore(start) && !day.isAfter(end)) {
        return true;
      }
    }

    return false;
  }

  /// [locations]' own permit windows, at most one entry per location — this model holds one permit
  /// document per location today ([OcptLocation.permitDocument]), while the pure rule reads a
  /// **list** per location so the day a location can file several permits, this join is the only
  /// thing that needs to change. A location with no permit document at all, or one recording
  /// neither `OcptAssetRef.validFrom` nor `OcptAssetRef.validUntil`, contributes an **empty**
  /// list — the caller's own reading of "no permit on file", which
  /// `lib/utils/ocpt_schedule_alerts.dart`'s own permit rule treats identically to a location that
  /// never declared one at all (that file's own doc comment).
  late final Map<String, List<OcptSchedulePermitWindow>> _permitWindowsByLocationId = {
    for (final location in locations)
      location.id: [
        if (location.permitDocument case final permit?)
          if (permit.validFrom != null || permit.validUntil != null)
            OcptSchedulePermitWindow(validFrom: permit.validFrom, validUntil: permit.validUntil),
      ],
  };

  /// Every [OcptScheduleAlert] the eleven rules of `lib/utils/ocpt_schedule_alerts.dart` raise over
  /// the whole schedule, computed **once**, on first read, rather than per read — see the class doc
  /// comment and [OcptSchedulePlanSnapshot]'s own constructor doc comment for why this is a
  /// `late final` field rather than a getter.
  ///
  /// Every join that function needs onto `shots`, `roles`, `people` and `locations` happens here —
  /// [_alertDayOf], [_roleIdByNormalizedName], [_permitWindowsByLocationId] and the location/people
  /// mappings below — exactly as [_convocationSlotOf] joins onto `roles` for [convocationsOfDay].
  /// `ocpt_schedule_alerts.dart` itself knows none of those tables.
  late final List<OcptScheduleAlert> alerts = ocptComputeScheduleAlerts(
    days: [for (final day in schedule.days) _alertDayOf(day)],
    people: [
      for (final person in people)
        OcptScheduleAlertPerson(
          id: person.id,
          maxDailyPresenceMinutes: person.maxDailyPresenceMinutes,
          unavailabilities: [
            for (final unavailability in person.unavailabilities)
              OcptScheduleAlertUnavailability(
                id: unavailability.id,
                startDate: unavailability.startDate,
                endDate: unavailability.endDate,
                dayPart: unavailability.slot,
                startMinute: unavailability.startMinute,
                endMinute: unavailability.endMinute,
              ),
          ],
        ),
    ],
    roles: [
      for (final role in roles) OcptScheduleAlertRole(id: role.id, personId: role.personId),
    ],
    locationWindowsByLocationId: {
      for (final location in locations)
        location.id: [
          for (final availability in location.availabilities)
            OcptScheduleAlertLocationWindow(
              startDate: availability.startDate,
              endDate: availability.endDate,
              weekdays: availability.weekdays,
              dayPart: availability.slot,
              startMinute: availability.startMinute,
              endMinute: availability.endMinute,
            ),
        ],
    },
    minimumRestMinutes: minimumRestMinutes,
    permitWindowsByLocationId: _permitWindowsByLocationId,
  );

  /// [alerts] grouped by the day each of them concerns (`ocptGroupScheduleAlertsByDay`) — what
  /// every day-level indicator of the mode reads, so the day cards, the three agendas and the day
  /// view's own summary band all mark exactly the days the `Alerts` panel lists.
  ///
  /// Derived from [alerts] rather than computed a second time, and `late final` for the same reason
  /// it is: the whole-shoot walk runs once per snapshot, and this grouping rides on it. A day
  /// raising nothing has no entry at all, and [OcptScheduleRoleUncastAlert] marks no day — see
  /// `ocptGroupScheduleAlertsByDay` for why.
  late final Map<String, List<OcptScheduleAlert>> alertsByDayId = ocptGroupScheduleAlertsByDay(alerts);

  /// Every [OcptRole.name] of [roles], normalised through `fountain_kit`'s `normalizeCharacterName`
  /// and keyed onto its own id — the same join `OcptCallSheetPdfService` and
  /// `OcptShootingPlanPdfService` already read a shot's characters through. Built once, alongside
  /// [alerts], rather than once per day.
  late final Map<String, String> _roleIdByNormalizedName = {
    for (final role in roles) normalizeCharacterName(role.name): role.id,
  };

  /// Builds [day]'s own [OcptScheduleAlertDay]: its live slots ([_alertSlotOf]), the timeline
  /// diagnostics [timelinesOfDay] already computes for it, and the roles a shot placed on it calls
  /// for ([_calledRolesOfDay]).
  OcptScheduleAlertDay _alertDayOf(OcptShootingDay day) {
    final slots = schedule.slotsByDayId[day.id] ?? const <OcptShootingSlot>[];
    final timelines = timelinesOfDay(day.id);

    return OcptScheduleAlertDay(
      id: day.id,
      date: day.date,
      slots: [
        // Every slot of [slots] was just handed to [timelinesOfDay] above, so each has its own
        // entry back: the `!`s are that round trip, not an assumption about the data (mirrors
        // [convocationsOfDay]'s own).
        for (final slot in slots) _alertSlotOf(slot, timelines!.bySlotId[slot.id]!),
      ],
      overruns: timelines?.overruns ?? const [],
      fixedEndMisses: timelines?.fixedEndMisses ?? const [],
      calledRoles: _calledRolesOfDay(day.id),
    );
  }

  /// Builds [slot]'s own [OcptScheduleAlertSlot]: its resolved band (from [timeline]), who is
  /// convoked on it as a human ([OcptScheduleAlertSlot.personIds], the same computation
  /// [_convocationSlotOf] makes for [convocationsOfDay]) and which roles it convokes at all, cast or
  /// not ([OcptScheduleAlertSlot.convokedRoleIds]).
  OcptScheduleAlertSlot _alertSlotOf(OcptShootingSlot slot, OcptShootingSlotTimeline timeline) {
    final personIds = <String>{for (final member in slot.crew) member.personId};
    final convokedRoleIds = <String>{};
    for (final member in slot.cast) {
      convokedRoleIds.add(member.roleId);
      final actorId = roleById[member.roleId]?.personId;
      if (actorId != null) {
        personIds.add(actorId);
      }
    }

    return OcptScheduleAlertSlot(
      id: slot.id,
      startMinute: timeline.startMinute,
      endMinute: timeline.endMinute,
      locationId: slot.locationId,
      personIds: personIds,
      convokedRoleIds: convokedRoleIds,
    );
  }

  /// Every role a shot placed on [dayId] calls for, one [OcptScheduleAlertCalledRole] per matched
  /// character of every `shot` block of that day's own blocks, in block order. A character with no
  /// matching role (through [_roleIdByNormalizedName]) names nothing this rule can act on and is
  /// silently skipped, exactly as `OcptShootingPlanPdfService._roleNamesOf` skips one.
  List<OcptScheduleAlertCalledRole> _calledRolesOfDay(String dayId) {
    final blocks = schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[];
    final calledRoles = <OcptScheduleAlertCalledRole>[];

    for (final block in blocks) {
      if (block.kind != OcptShootingBlockKind.shot || block.shotId == null) {
        continue;
      }
      final shot = shotById(block.shotId!);
      if (shot == null) {
        continue;
      }
      for (final character in shot.characters) {
        final roleId = _roleIdByNormalizedName[character];
        if (roleId != null) {
          calledRoles.add(OcptScheduleAlertCalledRole(roleId: roleId, shotId: shot.id));
        }
      }
    }

    return calledRoles;
  }

  /// Object properties
  @override
  List<Object?> get props => [
    schedule,
    shotLists,
    episodes,
    locations,
    roles,
    people,
    elements,
    roleCandidates,
    minimumRestMinutes,
    locationById,
    setById,
    roleById,
    personById,
    roleCandidateById,
    episodeById,
    shotsById,
  ];
}
