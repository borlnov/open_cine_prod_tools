// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_blocks_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_convocations_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_days_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_slots_ops.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// CRUD over a screenplay's shooting schedule: its days, the convocation windows inside each day
/// (`shooting_slots`), who is convoked in each (`shooting_slot_crew`/`shooting_slot_cast`), and
/// each **slot's own** timetable (`shooting_day_blocks`) — placing a shot, reserving a `hold`, and
/// the milestones (preparation, hair/make-up, a meal, a travel move, the wrap) interleaved between
/// them.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — these six tables have no `position` column at all,
/// schema v11 having been declared after `sortKey` already existed, so there is no legacy column
/// to leave alone.
///
/// **A day's printed number (`J3`) is a read-time rank, never a column.** [loadSchedule] counts it
/// off the same way `OcptShotListService` counts a shot's `OcptShot.position`: the 1-based index of
/// a live day among its screenplay's days, ordered by `sortKey`.
///
/// **A day is a set of parallel chains, one per slot, rather than one timetable.** A block belongs
/// to exactly one slot ([createBlock]/[placeShot] both take a required slot id and read the day off
/// it, so a block can never name a day its slot doesn't belong to) and chains from that slot's own
/// `startMinute` — see `lib/models/rules/ocpt_shooting_day_timeline.dart` (ADR 0015, amended).
///
/// **A convocation is what you are linked to, and nothing about it is typed** — see
/// `lib/models/rules/ocpt_shooting_convocations.dart` (ADR 0018). For everybody but a candidate
/// that is a **slot**; a candidate is linked to the **audition block** that sees them
/// ([addBlockCandidate], `shooting_block_candidates`, ADR 0024), because somebody seen for a part
/// is expected at twenty past ten rather than "on this unit today" — the one convocation in this
/// app read off a block. [addSlotCrewMember]/[addSlotCastRole] do
/// nothing more than create the link: a person's or a role's arrival, readiness band and departure
/// are read off every live slot they are linked to across the whole day, joined together, never
/// stored on the row itself and never typed beside it. A production that wants somebody there
/// earlier — a make-up call, a rigging call — creates the slot that says so, with its own label and
/// its own blocks, and links them to it; this service exposes no way to offset a convocation from
/// its slot instead.
///
/// **`person_positions` is what a fresh crew row's position is pre-filled from, and only that** —
/// see `lib/models/rules/ocpt_crew_position_prefill.dart`. [addSlotCrewMember] reads a person's
/// declared positions and what they already hold on the slot being added to, and lands on their
/// first declared position not already taken there; nothing stops a user changing it afterwards,
/// and nothing keeps the two tables in step once it has.
///
/// **A slot is pinned by one edge, and that edge may read another slot's.** [createSlot] mints a
/// slot anchored by its **start** at a typed hour, exactly as every slot was before schema version
/// 14; [setSlotAnchor] is the one entry point that changes an anchor afterwards, and it refuses
/// anything that isn't a live slot of the same day, the slot itself, or a link that would close a
/// circle (`ocptSlotAnchorWouldCycle`) — so `ocptComputeShootingDayTimelines`' own cycle rule stays
/// a defence against a file rather than a state this service can put a project in. Two rules follow
/// from links existing at all: [duplicateDay] **remaps them onto the copies** (a copy linked to the
/// original day's slot would be a cross-day link, which nothing allows), and [deleteSlot]
/// **freezes its dependents** — each slot reading the deleted one's edge keeps the hour it was
/// reading, as a typed anchor, so a deletion never silently moves a day.
///
/// **A shot may be placed as many times as the plan needs.** [placeShot] only ever creates: a shot
/// interrupted by the meal break and resumed after it is two blocks on the same day, not one, and a
/// shot picked up again on a later date is two blocks on two different days. A placement is *moved*
/// with [moveBlockToSlot] or the reorder, exactly like any other block, and *removed* with
/// [deleteBlock], exactly like any other block — there is no operation keyed by shot any more. This
/// costs the shot list's `Jour de tournage` read-out its single answer, which is why
/// [loadShotPlacements] returns a **list** per shot rather than one placement.
///
/// **Deleting a day cascades; deleting a slot moves what was scheduled inside it, or drops it with
/// the slot when there is nowhere left to move it to.** [deleteDay] tombstones everything hanging
/// off it — its slots, their crew, cast and guests, its blocks, and its own events — in one
/// transaction, the way `OcptLocationsService.deleteLocation` tombstones a location's sets.
/// [deleteSlot] is narrower: it tombstones the slot's own crew, cast and guests — a guest is
/// convoked by the slot exactly as a crew member or a role is, so removing it removes them along
/// with it — then moves the slot's own live blocks, in their own order, to the end of the day's
/// first *other* live slot (lowest `sortKey`) — removing a convocation window must not silently
/// unplace whatever was scheduled inside it, so its blocks simply join a different chain. When the
/// slot being deleted is the day's **last** live one, there is nowhere left for its blocks to go,
/// and they are tombstoned along with it — a decision taken deliberately: a block can never be
/// slotless (`shooting_day_blocks.slotId` is `NOT NULL` from schema v12), so a day with no slot at
/// all can hold no timetable either.
///
/// **Duplicating a day copies the shape of the crew, not the day's own work.** [duplicateDay]
/// copies the source day's slots, their crew, their cast and their guests — but copies **neither
/// the placed shots nor the crew note**, and (a decision this service makes on its own) starts the
/// new day's own `status`, `weatherNote` and `notes` at their column defaults too: a stable crew is
/// entered once for a whole shoot and reused day after day, while what got shot, what the weather
/// did and why a day was lost are all facts of the specific day being duplicated *away* from, not
/// of the one being planned. A guest is entered once for the same reason a crew member is — a
/// location owner attending every day of a shoot should not be re-typed each time. The source day's
/// **events are not copied**: a guest attends a shoot, but an event happens on a date, and carrying
/// the village fireworks over to a day re-planned at another date would be the app inventing a fact
/// about it.
///
/// **A guest is convoked by the slot exactly as a crew member or a role is, and an event is not
/// convoked at all.** [addSlotGuest]/[updateSlotGuest]/[deleteSlotGuest] mirror the crew and cast
/// methods above — appended at the end of the slot's own guests, the discriminator
/// (`personId`/`freeName`) guaranteed rather than hoped for — because a guest's arrival and
/// departure are read off the slots they are linked to (ADR 0018) exactly as everybody else's are.
/// [createDayEvent]/[updateDayEvent]/[deleteDayEvent] have no such reading: an event is a fact
/// about the day at an absolute hour, ordered by that hour alone, so there is no reorder method for
/// it — moving one is typing another [OcptShootingDayEvent.minute].
///
/// **The presence grid has nothing of its own to write.** `shooting_presences`, the by-hand
/// override schema v11 declared for it, is dropped again at schema v17: every cell it drew is
/// **computed**, from that day's convocations and from `person_unavailabilities` — see
/// `OcptSchedulePlanSnapshot.presenceCellOf` — so this service holds no writer for it at all.
class OcptScheduleService extends AbsOcptService {
  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [tombstoneShotBlocks] never calls it: it writes inside a caller's own
  /// transaction, and takes that caller's own [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptScheduleService({required super.logger, required this.deviceId});

  /// Forward to [OcptScheduleDaysOps.loadSchedule].
  Future<OcptScheduleSnapshot> loadSchedule({required OcptProjectDatabase database}) =>
      OcptScheduleDaysOps.loadSchedule(database: database);

  /// Forward to [OcptScheduleDaysOps.loadShotPlacements].
  Future<Map<String, List<OcptShotPlacement>>> loadShotPlacements({
    required OcptProjectDatabase database,
  }) => OcptScheduleDaysOps.loadShotPlacements(database: database);

  /// Forward to [OcptScheduleDaysOps.createDay].
  Future<String?> createDay({required OcptProjectDatabase database, required DateTime date}) =>
      OcptScheduleDaysOps.createDay(database: database, date: date, deviceId: deviceId);

  /// Forward to [OcptScheduleDaysOps.updateDay].
  Future<void> updateDay({
    required OcptProjectDatabase database,
    required String dayId,
    Value<DateTime> date = const Value.absent(),
    Value<OcptShootingDayStatus> status = const Value.absent(),
    Value<String> crewNote = const Value.absent(),
    Value<String> weatherNote = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) => OcptScheduleDaysOps.updateDay(
    database: database,
    dayId: dayId,
    date: date,
    status: status,
    crewNote: crewNote,
    weatherNote: weatherNote,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleDaysOps.deleteDay].
  Future<void> deleteDay({required OcptProjectDatabase database, required String dayId}) =>
      OcptScheduleDaysOps.deleteDay(database: database, dayId: dayId, deviceId: deviceId);

  /// Forward to [OcptScheduleDaysOps.duplicateDay].
  Future<String?> duplicateDay({
    required OcptProjectDatabase database,
    required String sourceDayId,
    required DateTime date,
  }) => OcptScheduleDaysOps.duplicateDay(
    database: database,
    sourceDayId: sourceDayId,
    date: date,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleSlotsOps.createSlot].
  Future<String?> createSlot({
    required OcptProjectDatabase database,
    required String shootingDayId,
    required int anchorMinute,
    String label = "",
    String? locationId,
    String? setId,
    String notes = "",
  }) => OcptScheduleSlotsOps.createSlot(
    database: database,
    shootingDayId: shootingDayId,
    anchorMinute: anchorMinute,
    label: label,
    locationId: locationId,
    setId: setId,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleSlotsOps.updateSlot].
  Future<void> updateSlot({
    required OcptProjectDatabase database,
    required String slotId,
    Value<String> label = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> setId = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) => OcptScheduleSlotsOps.updateSlot(
    database: database,
    slotId: slotId,
    label: label,
    locationId: locationId,
    setId: setId,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleSlotsOps.setSlotAnchor].
  Future<bool> setSlotAnchor({
    required OcptProjectDatabase database,
    required String slotId,
    required OcptShootingSlotAnchorEdge edge,
    int? minute,
    String? sourceSlotId,
  }) => OcptScheduleSlotsOps.setSlotAnchor(
    database: database,
    slotId: slotId,
    edge: edge,
    minute: minute,
    sourceSlotId: sourceSlotId,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleSlotsOps.reorderSlot].
  Future<void> reorderSlot({
    required OcptProjectDatabase database,
    required String slotId,
    required int newPosition,
  }) => OcptScheduleSlotsOps.reorderSlot(
    database: database,
    slotId: slotId,
    newPosition: newPosition,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleSlotsOps.deleteSlot].
  Future<void> deleteSlot({required OcptProjectDatabase database, required String slotId}) =>
      OcptScheduleSlotsOps.deleteSlot(database: database, slotId: slotId, deviceId: deviceId);

  /// Forward to [OcptScheduleConvocationsOps.addSlotCrewMember].
  Future<String?> addSlotCrewMember({
    required OcptProjectDatabase database,
    required String slotId,
    required String personId,
    String positionId = "",
    String customLabel = "",
    String notes = "",
  }) => OcptScheduleConvocationsOps.addSlotCrewMember(
    database: database,
    slotId: slotId,
    personId: personId,
    positionId: positionId,
    customLabel: customLabel,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.updateSlotCrewMember].
  Future<void> updateSlotCrewMember({
    required OcptProjectDatabase database,
    required String crewMemberId,
    Value<String> personId = const Value.absent(),
    Value<String> positionId = const Value.absent(),
    Value<String> customLabel = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) => OcptScheduleConvocationsOps.updateSlotCrewMember(
    database: database,
    crewMemberId: crewMemberId,
    personId: personId,
    positionId: positionId,
    customLabel: customLabel,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.removeSlotCrewMember].
  Future<void> removeSlotCrewMember({
    required OcptProjectDatabase database,
    required String crewMemberId,
  }) => OcptScheduleConvocationsOps.removeSlotCrewMember(
    database: database,
    crewMemberId: crewMemberId,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.addSlotCastRole].
  Future<String?> addSlotCastRole({
    required OcptProjectDatabase database,
    required String slotId,
    required String roleId,
    String notes = "",
  }) => OcptScheduleConvocationsOps.addSlotCastRole(
    database: database,
    slotId: slotId,
    roleId: roleId,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.updateSlotCastRole].
  Future<void> updateSlotCastRole({
    required OcptProjectDatabase database,
    required String castRoleId,
    Value<String> notes = const Value.absent(),
  }) => OcptScheduleConvocationsOps.updateSlotCastRole(
    database: database,
    castRoleId: castRoleId,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.removeSlotCastRole].
  Future<void> removeSlotCastRole({
    required OcptProjectDatabase database,
    required String castRoleId,
  }) => OcptScheduleConvocationsOps.removeSlotCastRole(
    database: database,
    castRoleId: castRoleId,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.addSlotGuest].
  Future<String?> addSlotGuest({
    required OcptProjectDatabase database,
    required String slotId,
    String? personId,
    String? freeName,
    String reason = "",
    String notes = "",
  }) => OcptScheduleConvocationsOps.addSlotGuest(
    database: database,
    slotId: slotId,
    personId: personId,
    freeName: freeName,
    reason: reason,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.updateSlotGuest].
  Future<void> updateSlotGuest({
    required OcptProjectDatabase database,
    required String guestId,
    Value<String?> personId = const Value.absent(),
    Value<String> freeName = const Value.absent(),
    Value<String> reason = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) => OcptScheduleConvocationsOps.updateSlotGuest(
    database: database,
    guestId: guestId,
    personId: personId,
    freeName: freeName,
    reason: reason,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.deleteSlotGuest].
  Future<void> deleteSlotGuest({required OcptProjectDatabase database, required String guestId}) =>
      OcptScheduleConvocationsOps.deleteSlotGuest(
        database: database,
        guestId: guestId,
        deviceId: deviceId,
      );

  /// Forward to [OcptScheduleConvocationsOps.addBlockCandidate].
  Future<String?> addBlockCandidate({
    required OcptProjectDatabase database,
    required String blockId,
    required String roleCandidateId,
    String notes = "",
  }) => OcptScheduleConvocationsOps.addBlockCandidate(
    database: database,
    blockId: blockId,
    roleCandidateId: roleCandidateId,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.updateBlockCandidate].
  Future<void> updateBlockCandidate({
    required OcptProjectDatabase database,
    required String blockCandidateId,
    Value<String> notes = const Value.absent(),
  }) => OcptScheduleConvocationsOps.updateBlockCandidate(
    database: database,
    blockCandidateId: blockCandidateId,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.reorderBlockCandidate].
  Future<void> reorderBlockCandidate({
    required OcptProjectDatabase database,
    required String blockCandidateId,
    required int newPosition,
  }) => OcptScheduleConvocationsOps.reorderBlockCandidate(
    database: database,
    blockCandidateId: blockCandidateId,
    newPosition: newPosition,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleConvocationsOps.removeBlockCandidate].
  Future<void> removeBlockCandidate({
    required OcptProjectDatabase database,
    required String blockCandidateId,
  }) => OcptScheduleConvocationsOps.removeBlockCandidate(
    database: database,
    blockCandidateId: blockCandidateId,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleDaysOps.createDayEvent].
  Future<String?> createDayEvent({
    required OcptProjectDatabase database,
    required String dayId,
    required int minute,
    String label = "",
    String notes = "",
  }) => OcptScheduleDaysOps.createDayEvent(
    database: database,
    dayId: dayId,
    minute: minute,
    label: label,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleDaysOps.updateDayEvent].
  Future<void> updateDayEvent({
    required OcptProjectDatabase database,
    required String eventId,
    Value<int> minute = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) => OcptScheduleDaysOps.updateDayEvent(
    database: database,
    eventId: eventId,
    minute: minute,
    label: label,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleDaysOps.deleteDayEvent].
  Future<void> deleteDayEvent({required OcptProjectDatabase database, required String eventId}) =>
      OcptScheduleDaysOps.deleteDayEvent(database: database, eventId: eventId, deviceId: deviceId);

  /// Forward to [OcptScheduleBlocksOps.placeShot].
  Future<String?> placeShot({
    required OcptProjectDatabase database,
    required String slotId,
    required String shotId,
    int? atPosition,
  }) => OcptScheduleBlocksOps.placeShot(
    database: database,
    slotId: slotId,
    shotId: shotId,
    atPosition: atPosition,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleBlocksOps.deleteBlock].
  Future<void> deleteBlock({required OcptProjectDatabase database, required String blockId}) =>
      OcptScheduleBlocksOps.deleteBlock(database: database, blockId: blockId, deviceId: deviceId);

  /// Forward to [OcptScheduleBlocksOps.createBlock].
  Future<String?> createBlock({
    required OcptProjectDatabase database,
    required String slotId,
    required OcptShootingBlockKind kind,
    String? sceneId,
    String label = "",
    int? durationMinutes,
    int? anchorMinute,
    String notes = "",
    int? atPosition,
  }) => OcptScheduleBlocksOps.createBlock(
    database: database,
    slotId: slotId,
    kind: kind,
    sceneId: sceneId,
    label: label,
    durationMinutes: durationMinutes,
    anchorMinute: anchorMinute,
    notes: notes,
    atPosition: atPosition,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleBlocksOps.updateBlock].
  Future<void> updateBlock({
    required OcptProjectDatabase database,
    required String blockId,
    Value<OcptShootingBlockKind> kind = const Value.absent(),
    Value<String?> sceneId = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int?> durationMinutes = const Value.absent(),
    Value<int?> anchorMinute = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String> crewNote = const Value.absent(),
  }) => OcptScheduleBlocksOps.updateBlock(
    database: database,
    blockId: blockId,
    kind: kind,
    sceneId: sceneId,
    label: label,
    durationMinutes: durationMinutes,
    anchorMinute: anchorMinute,
    notes: notes,
    crewNote: crewNote,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleBlocksOps.reorderBlock].
  Future<void> reorderBlock({
    required OcptProjectDatabase database,
    required String blockId,
    required int newPosition,
  }) => OcptScheduleBlocksOps.reorderBlock(
    database: database,
    blockId: blockId,
    newPosition: newPosition,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleBlocksOps.moveBlockToSlot].
  Future<void> moveBlockToSlot({
    required OcptProjectDatabase database,
    required String blockId,
    required String targetSlotId,
    required int newPosition,
  }) => OcptScheduleBlocksOps.moveBlockToSlot(
    database: database,
    blockId: blockId,
    targetSlotId: targetSlotId,
    newPosition: newPosition,
    deviceId: deviceId,
  );

  /// Forward to [OcptScheduleBlocksOps.tombstoneShotBlocks].
  Future<void> tombstoneShotBlocks({
    required OcptProjectDatabase database,
    required List<String> shotIds,
    required OcptRowStampService? stamps,
  }) => OcptScheduleBlocksOps.tombstoneShotBlocks(
    database: database,
    shotIds: shotIds,
    stamps: stamps,
  );
}
