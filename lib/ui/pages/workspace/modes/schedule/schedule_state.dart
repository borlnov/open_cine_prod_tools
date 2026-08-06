// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The key [OcptScheduleState.pendingFieldEdits] is stored under: which entity, and which of its
/// own [OcptScheduleField]s.
typedef OcptSchedulePendingFieldKey = (String targetId, OcptScheduleField field);

/// One group of the left dock's own "shots still to place" list: every live shot of one sequence
/// (a real scene, or the orphan group) that has no live block placing it yet, in the sequence's own
/// shot order.
class OcptScheduleUnplacedGroup extends Equatable {
  /// The sequence's own id (a scene id, or `OcptOrphanShotSequence.sequenceId`).
  final String sequenceId;

  /// The sequence's own display number (`4A`), or null for the orphan group.
  final String? displaySceneNumber;

  /// The sequence's own heading, or null for the orphan group.
  final String? heading;

  /// The unplaced shots of this sequence, in shot order.
  final List<OcptShot> shots;

  /// Class constructor
  const OcptScheduleUnplacedGroup({
    required this.sequenceId,
    required this.displaySceneNumber,
    required this.heading,
    required this.shots,
  });

  /// Object properties
  @override
  List<Object?> get props => [sequenceId, displaySceneNumber, heading, shots];
}

/// The state of `OcptScheduleBloc`.
///
/// [pendingFieldEdits] is the schedule mode's own single pending-edit map, over every free-text
/// field of every entity the mode edits text on — see `OcptScheduleField`'s own doc comment for
/// why one flat map rather than one per entity. [placingShotId], like
/// `OcptBreakdownState.pendingTagAnchor`, writes nothing to the project database on its own: the
/// database is only touched once a day answers it (`OcptScheduleShotPlacedEvent`).
class OcptScheduleState extends BlocStateForMixin<OcptScheduleState>
    with MixinOcptProjectVersionsState<OcptScheduleState> {
  /// The duration, in minutes, a block resolves to when it has neither its own `durationMinutes`
  /// nor (for a shot block) an estimate to fall back to — `ocptComputeShootingDayTimelines`'s own
  /// `defaultDurationMinutes`, decided once here so every timeline this state computes agrees.
  static const int defaultBlockDurationMinutes = 30;

  /// Whether the schedule read is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole schedule read, as last loaded from the project database, or null while nothing has
  /// been read yet.
  final OcptScheduleSnapshot? snapshot;

  /// The whole shot list read, as last loaded — what every placed or unplaced shot's own code,
  /// size, duration and characters are resolved from. Null while nothing has been read yet.
  final OcptShotListSnapshot? shotListSnapshot;

  /// The project's whole location catalogue (with their sets), as last loaded — what a slot's
  /// place is resolved from and a day's own tint is read off.
  final List<OcptLocation> locations;

  /// The project's whole cast, as last loaded — what the slot cards' cast picker offers, once
  /// built.
  final List<OcptRole> roles;

  /// The project's whole address book, as last loaded — what the slot cards' crew picker offers,
  /// once built.
  final List<OcptPerson> people;

  /// The id of the currently selected day, or null while none is — which, past a load, only
  /// happens in a project holding no day at all: the mode opens on the day view, so a load picks a
  /// day to show rather than landing the user on an empty surface.
  final String? selectedDayId;

  /// The id of the currently selected block, or null while none is. Always the id of a block
  /// belonging to [selectedDayId] — see `OcptScheduleBlockSelectedEvent`.
  final String? selectedBlockId;

  /// Which of the two centre views (agenda or day) is currently shown.
  final OcptScheduleCentreView centreView;

  /// Which of the three agenda presentations is currently shown.
  final OcptScheduleAgendaMode agendaMode;

  /// Which day a week starts on, read once per load from the user's own app-wide preference — what
  /// the week and month agendas cut their columns on.
  final OcptFirstWeekday firstWeekday;

  /// The date the week/month agenda pages through — the week or the month it shows is the one this
  /// date falls in. Reset to the first live day's date (or today, with none) on every load.
  final DateTime agendaAnchorDate;

  /// Whether the left (days) dock is shown.
  final bool isListPanelVisible;

  /// The right dock's currently active tab, or null if the dock is closed.
  final OcptScheduleRightDockTab? rightDockTab;

  /// The tab the toolbar's right-dock toggle reopens a closed dock on: the last one explicitly
  /// selected, mirroring `OcptBreakdownState.lastRightDockTab`.
  final OcptScheduleRightDockTab lastRightDockTab;

  /// The id of the shot currently being *placed* — picked up from the left dock's own "shots still
  /// to place" list, waiting for a day to answer it — or null while no placing is in progress.
  final String? placingShotId;

  /// Every free-text field still sitting in the field-edit debounce, keyed by which entity and
  /// which of its own fields. [fieldValueOf] is what a field reads instead of its own stored value
  /// while an edit is pending here.
  final Map<OcptSchedulePendingFieldKey, String> pendingFieldEdits;

  /// The left (days) dock's width, as a fraction of the mode's content row width. Persisted
  /// through `OcptPropertiesManager.scheduleLeftDockFraction`.
  final double leftDockFraction;

  /// The right (inspector/versions) dock's width, as a fraction of the mode's content row width.
  /// Persisted through `OcptPropertiesManager.scheduleRightDockFraction`.
  final double rightDockFraction;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersions}
  @override
  final List<OcptProjectVersion> projectVersions;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.previewedVersionId}
  @override
  final String? previewedVersionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.workingCopy}
  @override
  final OcptProjectWorkingCopyState? workingCopy;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingDeletionId}
  @override
  final String? versionPendingDeletionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingRestoreId}
  @override
  final String? versionPendingRestoreId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingRenameId}
  @override
  final String? versionPendingRenameId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersionNotice}
  @override
  final OcptProjectVersionNoticeKind? projectVersionNotice;

  /// Every live day of [snapshot], in `dayNumber` order (empty while nothing is loaded).
  List<OcptShootingDay> get days => snapshot?.days ?? const [];

  /// Every day of [days], keyed by its id.
  Map<String, OcptShootingDay> get daysById => snapshot?.daysById ?? const {};

  /// The number of live days — the status bar's own first counter.
  int get dayCount => snapshot?.dayCount ?? 0;

  /// The number of shots placed somewhere in the schedule — the status bar's own second counter.
  int get placedShotCount => snapshot?.placedShotIds.length ?? 0;

  /// Every live shot of the current shot list, across every sequence including the orphan group.
  List<OcptShot> get _allShots => [
    for (final sequence in shotListSnapshot?.sequences ?? const <OcptShotSequence>[]) ...sequence.shots,
  ];

  /// The number of shots that still have no live block placing them — the status bar's own third
  /// counter, and what [unplacedGroups] lists.
  int get shotsLeftToPlaceCount {
    final placedShotIds = snapshot?.placedShotIds ?? const <String>{};
    return _allShots.where((shot) => !placedShotIds.contains(shot.id)).length;
  }

  /// The selected day, or null while none is selected (or the selected one disappeared from a
  /// freshly loaded [snapshot]).
  OcptShootingDay? get selectedDay {
    final selectedDayId = this.selectedDayId;
    return selectedDayId == null ? null : daysById[selectedDayId];
  }

  /// The selected block, or null while none is selected (or it disappeared, or its own day did).
  OcptShootingDayBlock? get selectedBlock {
    final selectedDayId = this.selectedDayId;
    final selectedBlockId = this.selectedBlockId;
    if (selectedDayId == null || selectedBlockId == null) {
      return null;
    }

    for (final block in snapshot?.blocksByDayId[selectedDayId] ?? const <OcptShootingDayBlock>[]) {
      if (block.id == selectedBlockId) {
        return block;
      }
    }

    return null;
  }

  /// The whole location catalogue, keyed by id.
  Map<String, OcptLocation> get locationById => {for (final location in locations) location.id: location};

  /// Every set of every location of [locations], keyed by id.
  Map<String, OcptSet> get setById => {
    for (final location in locations)
      for (final set in location.sets) set.id: set,
  };

  /// The whole cast, keyed by id.
  Map<String, OcptRole> get roleById => {for (final role in roles) role.id: role};

  /// The whole address book, keyed by id.
  Map<String, OcptPerson> get personById => {for (final person in people) person.id: person};

  /// The shot [shotId] names, or null while [shotListSnapshot] hasn't loaded it (or it has since
  /// been deleted).
  OcptShot? shotById(String shotId) => shotListSnapshot?.shotsById[shotId];

  /// [selectedDayId]'s own live slots, in `sortKey` order (empty while none is selected, or the
  /// selected day carries none).
  List<OcptShootingSlot> get selectedDaySlots {
    final selectedDayId = this.selectedDayId;
    return selectedDayId == null
        ? const []
        : (snapshot?.slotsByDayId[selectedDayId] ?? const []);
  }

  /// [selectedDayId]'s own live blocks — its timetable — in `sortKey` order.
  List<OcptShootingDayBlock> get selectedDayBlocks {
    final selectedDayId = this.selectedDayId;
    return selectedDayId == null
        ? const []
        : (snapshot?.blocksByDayId[selectedDayId] ?? const []);
  }

  /// The live shots still to place, grouped by the sequence they belong to, sequences in their own
  /// screenplay order and each group's shots in their own sequence order. A sequence with nothing
  /// left to place has no entry at all.
  ///
  /// Computed on every read rather than stored: the schedule mode never rebuilds on a per-keystroke
  /// timer the way the breakdown mode's own target suggestions do (nothing here is typed into), so
  /// there is no hot path this would need to be cached out of.
  List<OcptScheduleUnplacedGroup> get unplacedGroups {
    final placedShotIds = snapshot?.placedShotIds ?? const <String>{};
    final groups = <OcptScheduleUnplacedGroup>[];

    for (final sequence in shotListSnapshot?.sequences ?? const <OcptShotSequence>[]) {
      final unplaced = [
        for (final shot in sequence.shots)
          if (!placedShotIds.contains(shot.id)) shot,
      ];
      if (unplaced.isEmpty) {
        continue;
      }

      groups.add(
        OcptScheduleUnplacedGroup(
          sequenceId: sequence.id,
          displaySceneNumber: sequence is OcptSceneShotSequence ? sequence.displaySceneNumber : null,
          heading: sequence is OcptSceneShotSequence ? sequence.heading : null,
          shots: unplaced,
        ),
      );
    }

    return groups;
  }

  /// [dayId]'s own computed timelines (ADR 0015, amended per
  /// `docs/plans/schedule-slots-and-computed-convocations.md`), one chain per live slot, joined
  /// into a single [OcptShootingDayTimelines] — or null while the day has no live slot to chain at
  /// all.
  ///
  /// Computed here rather than stored, exactly as `docs/plans/schedule-mode.md` §8 asks: reading it
  /// costs nothing beyond a handful of list lookups already held in memory, and storing it would be
  /// one more thing every write to that day's blocks would have to remember to invalidate.
  OcptShootingDayTimelines? timelinesOfDay(String dayId) {
    final slots = snapshot?.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (slots.isEmpty) {
      return null;
    }

    final blocks = snapshot?.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[];
    final blocksBySlotId = <String, List<OcptShootingDayBlock>>{};
    for (final block in blocks) {
      (blocksBySlotId[block.slotId] ??= <OcptShootingDayBlock>[]).add(block);
    }

    final timelineSlots = [
      for (final slot in slots)
        OcptShootingTimelineSlot(
          id: slot.id,
          startMinute: slot.startMinute,
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
      defaultDurationMinutes: defaultBlockDurationMinutes,
    );
  }

  /// Every live slot of [snapshot], across every day, keyed by its own id — what [convocationsOfSlot]
  /// resolves its target slot's own day through.
  Map<String, OcptShootingSlot> get slotById => {
    for (final slots in snapshot?.slotsByDayId.values ?? const <List<OcptShootingSlot>>[])
      for (final slot in slots) slot.id: slot,
  };

  /// [slotId]'s own computed convocations (ADR 0017, `lib/utils/ocpt_shooting_convocations.dart`):
  /// every crew member's call/wrap and every convoked role's PAT band/arrival — or null while
  /// [slotId] names no live slot of [snapshot] (its day not loaded yet, or the slot itself since
  /// deleted).
  ///
  /// Built from that slot's own already-chained blocks ([timelinesOfDay]), its live crew and cast
  /// rows, and the lead time each row resolves to: its own [OcptShootingSlotCrewMember.leadMinutes]/
  /// [OcptShootingSlotCastMember.leadMinutes] when set, else its own group's
  /// [OcptShootingDayGroup.leadMinutes] looked up by `groupId` against the day's own
  /// [OcptScheduleSnapshot.groupsByDayId] — [ocptComputeSlotConvocations] is what actually resolves
  /// which one wins.
  OcptSlotConvocations? convocationsOfSlot(String slotId) {
    final slot = slotById[slotId];
    if (slot == null) {
      return null;
    }

    final slotTimeline = timelinesOfDay(slot.shootingDayId)?.bySlotId[slotId];
    final entryByBlockId = {
      for (final entry in slotTimeline?.entries ?? const <OcptShootingTimelineEntry>[])
        entry.blockId: entry,
    };
    final dayBlocks = snapshot?.blocksByDayId[slot.shootingDayId] ?? const <OcptShootingDayBlock>[];
    final groupLeadById = {
      for (final group in snapshot?.groupsByDayId[slot.shootingDayId] ?? const <OcptShootingDayGroup>[])
        group.id: group.leadMinutes,
    };

    final convocationBlocks = [
      for (final block in dayBlocks)
        if (block.slotId == slotId && entryByBlockId[block.id] != null)
          OcptConvocationBlock(
            startMinute: entryByBlockId[block.id]!.startMinute,
            endMinute: entryByBlockId[block.id]!.endMinute,
            roleIds: _roleIdsOfBlock(block),
          ),
    ];

    return ocptComputeSlotConvocations(
      slotStartMinute: slot.startMinute,
      blocks: convocationBlocks,
      crew: [
        for (final member in slot.crew)
          OcptCrewConvocationInput(
            id: member.id,
            leadMinutes: member.leadMinutes,
            groupLeadMinutes: member.groupId == null ? null : groupLeadById[member.groupId],
          ),
      ],
      cast: [
        for (final member in slot.cast)
          OcptCastConvocationInput(
            id: member.id,
            roleId: member.roleId,
            leadMinutes: member.leadMinutes,
            groupLeadMinutes: member.groupId == null ? null : groupLeadById[member.groupId],
          ),
      ],
    );
  }

  /// The roles [block] puts on the floor, fed to [ocptComputeSlotConvocations] as an
  /// [OcptConvocationBlock.roleIds] — a **shot** block's own shot's `shot_characters`, matched
  /// against [roles] by exact name (the same normalisation `OcptRoleIndexService.reconcile` and
  /// `OcptShotListService.attachCharacter` already apply to a character name, so a role's own name
  /// and a shot's own character are directly comparable with no further folding here); every other
  /// kind returns the empty set.
  ///
  /// A **hold** block reserves time for a sequence rather than a shot, and names it through
  /// `shooting_day_blocks.sceneId`. Nothing sets that column yet — the control that picks a hold's
  /// sequence comes with the day view's own rework, and so does reading the roles that sequence
  /// calls for out of the breakdown — so a hold still resolves to no role here, and a role convoked
  /// in a slot whose only content is a hold keeps the slot's own bounds, which is
  /// [ocptComputeSlotConvocations]'s own fallback for a role no block names.
  Set<String> _roleIdsOfBlock(OcptShootingDayBlock block) {
    if (block.kind != OcptShootingBlockKind.shot || block.shotId == null) {
      return const {};
    }

    final shot = shotById(block.shotId!);
    if (shot == null) {
      return const {};
    }

    return {
      for (final character in shot.characters)
        if (roleByName[character] != null) roleByName[character]!.id,
    };
  }

  /// The whole cast, keyed by its own name — what [_roleIdsOfBlock] matches a shot's characters
  /// against.
  Map<String, OcptRole> get roleByName => {for (final role in roles) role.name: role};

  /// [shotId]'s own `estimatedDurationMs`, converted to minutes, or null while it has none yet (or
  /// the shot isn't loaded).
  int? _durationMinutesOfShot(String shotId) {
    final estimatedDurationMs = shotById(shotId)?.estimatedDurationMs;
    return estimatedDurationMs == null ? null : (estimatedDurationMs / 60000).round();
  }

  /// [dayId]'s own computed sun and twilight times (ADR 0016), or null while its first live slot
  /// has no location, or that location has no coordinates pinned yet.
  OcptSunTimes? sunTimesOfDay(String dayId) {
    final day = daysById[dayId];
    final slots = snapshot?.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
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
    final slots = snapshot?.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    return slots.isEmpty ? null : locationById[slots.first.locationId];
  }

  /// [targetId]'s current value for `field` — a pending edit still sitting in [pendingFieldEdits],
  /// or [storedValue] (the entity's own value, read off the call site) otherwise.
  String fieldValueOf(String targetId, OcptScheduleField field, String storedValue) =>
      pendingFieldEdits[(targetId, field)] ?? storedValue;

  /// Class constructor
  const OcptScheduleState({
    required this.isLoading,
    required this.title,
    required this.snapshot,
    required this.shotListSnapshot,
    required this.locations,
    required this.roles,
    required this.people,
    required this.selectedDayId,
    required this.selectedBlockId,
    required this.centreView,
    required this.agendaMode,
    required this.firstWeekday,
    required this.agendaAnchorDate,
    required this.isListPanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.placingShotId,
    required this.pendingFieldEdits,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
  });

  /// Init class constructor
  OcptScheduleState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      shotListSnapshot = null,
      locations = const [],
      roles = const [],
      people = const [],
      selectedDayId = null,
      selectedBlockId = null,
      centreView = OcptScheduleCentreView.day,
      agendaMode = OcptScheduleAgendaMode.strip,
      firstWeekday = OcptFirstWeekday.monday,
      agendaAnchorDate = DateTime.now(),
      isListPanelVisible = true,
      rightDockTab = null,
      lastRightDockTab = OcptScheduleRightDockTab.inspector,
      placingShotId = null,
      pendingFieldEdits = const {},
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot] and [shotListSnapshot] are only replaced when a new one is given, exactly as
  /// `OcptBreakdownState.snapshot`. [selectedDayId], [selectedBlockId], [rightDockTab] and
  /// [placingShotId] all legitimately go back to null while the mode is alive, so each has its own
  /// clear flag. [pendingFieldEdits] is always replaced wholesale — the caller (the bloc's own
  /// field-edit handler) always computes the full next map.
  @override
  OcptScheduleState copyWith({
    bool? isLoading,
    String? title,
    OcptScheduleSnapshot? snapshot,
    OcptShotListSnapshot? shotListSnapshot,
    List<OcptLocation>? locations,
    List<OcptRole>? roles,
    List<OcptPerson>? people,
    String? selectedDayId,
    bool clearSelectedDayId = false,
    String? selectedBlockId,
    bool clearSelectedBlockId = false,
    OcptScheduleCentreView? centreView,
    OcptScheduleAgendaMode? agendaMode,
    OcptFirstWeekday? firstWeekday,
    DateTime? agendaAnchorDate,
    bool? isListPanelVisible,
    OcptScheduleRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptScheduleRightDockTab? lastRightDockTab,
    String? placingShotId,
    bool clearPlacingShotId = false,
    Map<OcptSchedulePendingFieldKey, String>? pendingFieldEdits,
    double? leftDockFraction,
    double? rightDockFraction,
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool clearWorkingCopy = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    String? versionPendingRestoreId,
    bool clearVersionPendingRestoreId = false,
    String? versionPendingRenameId,
    bool clearVersionPendingRenameId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
  }) => OcptScheduleState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? this.snapshot,
    shotListSnapshot: shotListSnapshot ?? this.shotListSnapshot,
    locations: locations ?? this.locations,
    roles: roles ?? this.roles,
    people: people ?? this.people,
    selectedDayId: clearSelectedDayId ? null : (selectedDayId ?? this.selectedDayId),
    selectedBlockId: clearSelectedBlockId ? null : (selectedBlockId ?? this.selectedBlockId),
    centreView: centreView ?? this.centreView,
    agendaMode: agendaMode ?? this.agendaMode,
    firstWeekday: firstWeekday ?? this.firstWeekday,
    agendaAnchorDate: agendaAnchorDate ?? this.agendaAnchorDate,
    isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    placingShotId: clearPlacingShotId ? null : (placingShotId ?? this.placingShotId),
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId: clearPreviewedVersionId ? null : (previewedVersionId ?? this.previewedVersionId),
    workingCopy: clearWorkingCopy ? null : (workingCopy ?? this.workingCopy),
    versionPendingDeletionId: clearVersionPendingDeletionId
        ? null
        : (versionPendingDeletionId ?? this.versionPendingDeletionId),
    versionPendingRestoreId: clearVersionPendingRestoreId
        ? null
        : (versionPendingRestoreId ?? this.versionPendingRestoreId),
    versionPendingRenameId: clearVersionPendingRenameId
        ? null
        : (versionPendingRenameId ?? this.versionPendingRenameId),
    projectVersionNotice: clearProjectVersionNotice
        ? null
        : (projectVersionNotice ?? this.projectVersionNotice),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptScheduleState copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool clearWorkingCopy = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    String? versionPendingRestoreId,
    bool clearVersionPendingRestoreId = false,
    String? versionPendingRenameId,
    bool clearVersionPendingRenameId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
  }) => copyWith(
    projectVersions: projectVersions,
    previewedVersionId: previewedVersionId,
    clearPreviewedVersionId: clearPreviewedVersionId,
    workingCopy: workingCopy,
    clearWorkingCopy: clearWorkingCopy,
    versionPendingDeletionId: versionPendingDeletionId,
    clearVersionPendingDeletionId: clearVersionPendingDeletionId,
    versionPendingRestoreId: versionPendingRestoreId,
    clearVersionPendingRestoreId: clearVersionPendingRestoreId,
    versionPendingRenameId: versionPendingRenameId,
    clearVersionPendingRenameId: clearVersionPendingRenameId,
    projectVersionNotice: projectVersionNotice,
    clearProjectVersionNotice: clearProjectVersionNotice,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    snapshot,
    shotListSnapshot,
    locations,
    roles,
    people,
    selectedDayId,
    selectedBlockId,
    centreView,
    agendaMode,
    firstWeekday,
    agendaAnchorDate,
    isListPanelVisible,
    rightDockTab,
    lastRightDockTab,
    placingShotId,
    pendingFieldEdits,
    leftDockFraction,
    rightDockFraction,
  ];
}
