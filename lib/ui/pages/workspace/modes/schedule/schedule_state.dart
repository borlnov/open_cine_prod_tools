// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The key [OcptScheduleState.pendingFieldEdits] is stored under: which entity, and which of its
/// own [OcptScheduleField]s.
typedef OcptSchedulePendingFieldKey = (String targetId, OcptScheduleField field);

/// One group of the left dock's own "shots still to place" list: every live shot of one sequence
/// (a real scene, or the orphan group) that has no live block placing it yet, in the sequence's own
/// shot order.
///
/// [screenplayId] names the episode this group's sequence belongs to. It is not cosmetic:
/// `OcptOrphanShotSequence.sequenceId` is the constant `"orphans"`, so a project holding several
/// episodes walks several groups sharing that one [sequenceId] — the pair ([screenplayId],
/// [sequenceId]) is what actually identifies one group once there is more than one episode to mix
/// them up.
class OcptScheduleUnplacedGroup extends Equatable {
  /// The id of the episode (screenplay) this group's sequence belongs to.
  final String screenplayId;

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
    required this.screenplayId,
    required this.sequenceId,
    required this.displaySceneNumber,
    required this.heading,
    required this.shots,
  });

  /// Object properties
  @override
  List<Object?> get props => [screenplayId, sequenceId, displaySceneNumber, heading, shots];
}

/// The kind of transient notice [OcptScheduleIoNotice] carries, one per schedule export outcome.
///
/// A folder export (the two call sheet kinds) is the one path with a middle ground between success
/// and failure — some files can be written while others aren't — which is why there are three kinds
/// rather than the two a single-file export would need: [folderExportPartiallySucceeded] must never
/// read as a plain success, `OcptCallSheetExportResult.failedFileNames` being non-empty meaning
/// exactly that someone's call sheet did not make it into the folder.
enum OcptScheduleIoNoticeKind {
  /// A single-file export (the shooting plan) was written successfully.
  fileExportSucceeded,

  /// A folder export (a call sheets run) wrote every file it set out to.
  folderExportSucceeded,

  /// A folder export wrote some files but not every one — `OcptCallSheetExportResult
  /// .failedFileNames` is non-empty.
  folderExportPartiallySucceeded,

  /// An export failed outright (an exception was thrown while rendering or writing it). A cancelled
  /// save/folder dialog is a silent no-op instead, exactly as the breakdown sheets export treats it.
  exportFailed,
}

/// A transient notice, produced by `OcptScheduleBloc`, reporting the outcome of one of the three
/// PDF exports, shown as a SnackBar then dismissed. Modelled on `OcptBreakdownIoNotice`.
///
/// Only the fields [kind] actually needs are ever set: [path] for [OcptScheduleIoNoticeKind
/// .fileExportSucceeded], [folderPath]/[writtenCount] for [OcptScheduleIoNoticeKind
/// .folderExportSucceeded], and all four but [path] for [OcptScheduleIoNoticeKind
/// .folderExportPartiallySucceeded]. [wasShared] can be set alongside any succeeded kind.
class OcptScheduleIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptScheduleIoNoticeKind kind;

  /// The path a single-file export was written to, only set when [kind] is [OcptScheduleIoNoticeKind
  /// .fileExportSucceeded] and [wasShared] is false.
  final String? path;

  /// The folder a folder export wrote into, only set for the two folder-export kinds — a temporary
  /// one rather than one the user picked when [wasShared] is true.
  final String? folderPath;

  /// How many files a folder export wrote successfully, only set for the two folder-export kinds.
  final int? writtenCount;

  /// How many files a folder export failed to write, only set for [OcptScheduleIoNoticeKind
  /// .folderExportPartiallySucceeded].
  final int? failedCount;

  /// Whether the export was handed to the OS share sheet rather than written to [path]/[folderPath]
  /// for the user to find — mobile's own outcome, `file_selector`'s `getSaveLocation`/
  /// `getDirectoryPath` having no Android or iOS implementation.
  final bool wasShared;

  /// Class constructor
  const OcptScheduleIoNotice({
    required this.kind,
    this.path,
    this.folderPath,
    this.writtenCount,
    this.failedCount,
    this.wasShared = false,
  });

  /// Object properties
  @override
  List<Object?> get props => [kind, path, folderPath, writtenCount, failedCount, wasShared];
}

/// The state of `OcptScheduleBloc`.
///
/// [pendingFieldEdits] is the schedule mode's own single pending-edit map, over every free-text
/// field of every entity the mode edits text on — see `OcptScheduleField`'s own doc comment for
/// why one flat map rather than one per entity. [selectedShotId] writes nothing to the project
/// database on its own: it is a selection, exactly like [selectedBlockId] beside it, only ever
/// naming which shot's own read-out the inspector currently shows.
class OcptScheduleState extends BlocStateForMixin<OcptScheduleState>
    with
        MixinOcptProjectVersionsState<OcptScheduleState>,
        MixinOcptProjectPackageState<OcptScheduleState> {
  /// Whether the schedule read is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole schedule read, as last loaded from the project database, or null while nothing has
  /// been read yet.
  final OcptScheduleSnapshot? snapshot;

  /// Every live episode's own shot list, as last loaded, in
  /// `OcptScreenplayService.loadEpisodes`' own order — what every placed or unplaced shot's own
  /// code, size, duration and characters are resolved from, across the whole project. Empty while
  /// nothing has been read yet.
  final List<OcptShotListSnapshot> shotListSnapshots;

  /// The project's live episodes, as last loaded, in the same order as [shotListSnapshots] — what
  /// [planSnapshot] names a scene's own screenplay through. Empty while nothing has been read yet.
  final List<OcptEpisode> episodes;

  /// The project's whole location catalogue (with their sets), as last loaded — what a slot's
  /// place is resolved from and a day's own tint is read off.
  final List<OcptLocation> locations;

  /// The project's whole cast, as last loaded — what the slot cards' cast picker offers, once
  /// built.
  final List<OcptRole> roles;

  /// The project's whole address book, as last loaded — what the slot cards' crew picker offers,
  /// once built.
  final List<OcptPerson> people;

  /// The project's whole elements catalogue, as last loaded — what a named call sheet's own "to
  /// bring" section reads through [planSnapshot].
  final List<OcptElement> elements;

  /// Every live candidacy of the project — who was seen for which part — as last loaded, in no
  /// particular order. What an `audition` block and a candidate's own convocation are resolved to a
  /// name and a part through, on the days that do not shoot; empty on a project that has auditioned
  /// nobody, which is most of them.
  final List<OcptRoleCandidate> roleCandidates;

  /// `project_info.minimumRestMinutes`, as last loaded — null while nobody has recorded one, which
  /// the rest-time alert never fires on. Read by the bloc's own load handler beside the page setup,
  /// and re-read by `OcptScheduleProjectSettingsChangedEvent` for the same reason that handler
  /// re-reads the page format: the project settings page is exactly where it is changed.
  final int? minimumRestMinutes;

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

  /// What fact the agenda currently tints a day with — session-only, unlike [firstWeekday] beside
  /// it (see [OcptScheduleAgendaColorMode]'s own doc comment).
  final OcptScheduleAgendaColorMode agendaColorMode;

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

  /// The id of the shot currently selected in the left dock's own "shots still to place" list, or
  /// null while none is — what the inspector shows a shot's own read-out for, mutually exclusive
  /// with [selectedBlockId] (see `OcptScheduleBlockSelectedEvent`/`OcptScheduleShotSelectedEvent`'s
  /// own doc comments).
  final String? selectedShotId;

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

  /// The page setup the three PDF exports are typeset with: the open project's own page format,
  /// paired with the app-wide margins preference, exactly as the shot list mode's own state pairs
  /// them for the scenario coverage export. Reloaded by `OcptScheduleProjectSettingsChangedEvent`,
  /// since page format is the one thing the project settings page can change under this mode.
  final OcptPageSetup pageSetup;

  /// The transient notice reporting the outcome of the last PDF export requested, or null once
  /// dismissed — see [OcptScheduleIoNotice]'s own doc comment.
  final OcptScheduleIoNotice? ioNotice;

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

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExport}
  @override
  final OcptProjectPackagePreflight? projectPackagePendingExport;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackageNotice}
  @override
  final OcptProjectPackageNotice? projectPackageNotice;

  /// [snapshot] joined with [shotListSnapshots]/[episodes]/[locations]/[roles]/[people] into the
  /// day-level facts the mode reads (`OcptSchedulePlanSnapshot`'s own doc comment) — null exactly
  /// while [snapshot] is, since a plan snapshot always carries a whole schedule read.
  ///
  /// Built **once per state instance**, on the first read, rather than on every read: a state is
  /// immutable and rebuilt per emit, so the join can never go stale inside one, and the mode reads
  /// it far too often for a per-read build — [timelinesOfDay] alone is handed to the three agendas
  /// as a function reference and called once per day cell, which on a month grid is thirty reads in
  /// a single frame. That is also why this is `late final` rather than a getter, and why the class
  /// constructor is not `const`: a `late final` field and a const constructor cannot coexist, and
  /// nothing ever built this state as a constant.
  late final OcptSchedulePlanSnapshot? planSnapshot = switch (snapshot) {
    null => null,
    final schedule => OcptSchedulePlanSnapshot.build(
      schedule: schedule,
      shotLists: shotListSnapshots,
      episodes: episodes,
      locations: locations,
      roles: roles,
      people: people,
      elements: elements,
      roleCandidates: roleCandidates,
      minimumRestMinutes: minimumRestMinutes,
    ),
  };

  /// Every live day of [snapshot], in `dayNumber` order (empty while nothing is loaded).
  List<OcptShootingDay> get days => snapshot?.days ?? const [];

  /// Every day of [days], keyed by its id.
  Map<String, OcptShootingDay> get daysById => snapshot?.daysById ?? const {};

  /// The number of live days — the status bar's own first counter.
  int get dayCount => snapshot?.dayCount ?? 0;

  /// The number of shots placed somewhere in the schedule — the status bar's own second counter.
  int get placedShotCount => snapshot?.placedShotIds.length ?? 0;

  /// Every live shot of every episode's own shot list, across every sequence including the orphan
  /// group, episode 1's before episode 2's — [shotListSnapshots]' own order.
  List<OcptShot> get _allShots => [
    for (final shotListSnapshot in shotListSnapshots)
      for (final sequence in shotListSnapshot.sequences) ...sequence.shots,
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

  /// The selected shot, or null while none is selected (or it disappeared from a freshly loaded
  /// [shotListSnapshots]) — mirrors [selectedBlock]'s own convention.
  OcptShot? get selectedShot {
    final selectedShotId = this.selectedShotId;
    return selectedShotId == null ? null : shotById(selectedShotId);
  }

  /// The whole location catalogue, keyed by id. Delegates to [planSnapshot], empty while it is
  /// null.
  Map<String, OcptLocation> get locationById => planSnapshot?.locationById ?? const {};

  /// Every set of every location of [locations], keyed by id. Delegates to [planSnapshot], empty
  /// while it is null.
  Map<String, OcptSet> get setById => planSnapshot?.setById ?? const {};

  /// The whole cast, keyed by id. Delegates to [planSnapshot], empty while it is null.
  Map<String, OcptRole> get roleById => planSnapshot?.roleById ?? const {};

  /// The whole address book, keyed by id. Delegates to [planSnapshot], empty while it is null.
  Map<String, OcptPerson> get personById => planSnapshot?.personById ?? const {};

  /// Every live candidacy, keyed by id — what an audition block's own row and a candidate's
  /// convocation card read their name and their part off. Delegates to [planSnapshot], empty while
  /// it is null.
  Map<String, OcptRoleCandidate> get roleCandidateById =>
      planSnapshot?.roleCandidateById ?? const {};

  /// The shot [shotId] names, or null while [shotListSnapshots] hasn't loaded it (or it has since
  /// been deleted). Delegates to [planSnapshot].
  OcptShot? shotById(String shotId) => planSnapshot?.shotById(shotId);

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

  /// [selectedDayId]'s own live events, ordered by [OcptShootingDayEvent.minute] then by
  /// `sortKey` — see `OcptScheduleSnapshot.eventsByDayId`.
  List<OcptShootingDayEvent> get selectedDayEvents {
    final selectedDayId = this.selectedDayId;
    return selectedDayId == null
        ? const []
        : (snapshot?.eventsByDayId[selectedDayId] ?? const []);
  }

  /// Every real scene of every episode's own [shotListSnapshots], as an [OcptSceneShotSequence],
  /// episode 1's before episode 2's — what a hold block's own sequence picker offers.
  /// [OcptOrphanShotSequence] is deliberately excluded: it names no `scenes` row, so
  /// `shooting_day_blocks.sceneId` could never point at it.
  List<OcptSceneShotSequence> get sceneSequences => [
    for (final shotListSnapshot in shotListSnapshots)
      for (final sequence in shotListSnapshot.sequences)
        if (sequence is OcptSceneShotSequence) sequence,
  ];

  /// The live shots still to place, grouped by the sequence they belong to, every episode's own
  /// sequences in their own screenplay order and episode 1's groups before episode 2's
  /// ([shotListSnapshots]' own order), each group's shots in their own sequence order. A sequence
  /// with nothing left to place has no entry at all.
  ///
  /// Computed on every read rather than stored: the schedule mode never rebuilds on a per-keystroke
  /// timer the way the breakdown mode's own target suggestions do (nothing here is typed into), so
  /// there is no hot path this would need to be cached out of.
  List<OcptScheduleUnplacedGroup> get unplacedGroups {
    final placedShotIds = snapshot?.placedShotIds ?? const <String>{};
    final groups = <OcptScheduleUnplacedGroup>[];

    for (final shotListSnapshot in shotListSnapshots) {
      for (final sequence in shotListSnapshot.sequences) {
        final unplaced = [
          for (final shot in sequence.shots)
            if (!placedShotIds.contains(shot.id)) shot,
        ];
        if (unplaced.isEmpty) {
          continue;
        }

        groups.add(
          OcptScheduleUnplacedGroup(
            screenplayId: shotListSnapshot.screenplayId,
            sequenceId: sequence.id,
            displaySceneNumber: sequence is OcptSceneShotSequence ? sequence.displaySceneNumber : null,
            heading: sequence is OcptSceneShotSequence ? sequence.heading : null,
            shots: unplaced,
          ),
        );
      }
    }

    return groups;
  }

  /// For every shot placed somewhere in the schedule, the day numbers it is placed on —
  /// deduplicated and in ascending order — keyed by shot id. A shot with no live block placing it
  /// has no entry here, read the same way an absent key reads everywhere else in this state: as
  /// "unplaced". What the shot picker dialog's own already-placed mark reads.
  ///
  /// Built from [snapshot]'s own [OcptScheduleSnapshot.blocksByDayId], one entry per **day** a shot
  /// is placed on rather than one per block, so a shot placed twice on the same day (interrupted by
  /// the meal break and resumed after it) still reports that day's number once. Computed on every
  /// read rather than stored, for the same reason [unplacedGroups] is: nothing here rides a
  /// per-keystroke timer that would need it cached.
  Map<String, List<int>> get placedDayNumbersByShotId {
    final dayNumbersByShotId = <String, Set<int>>{};

    for (final entry in snapshot?.blocksByDayId.entries ?? const <MapEntry<String, List<OcptShootingDayBlock>>>[]) {
      final dayNumber = daysById[entry.key]?.dayNumber;
      if (dayNumber == null) {
        continue;
      }

      for (final block in entry.value) {
        final shotId = block.shotId;
        if (block.kind == OcptShootingBlockKind.shot && shotId != null) {
          (dayNumbersByShotId[shotId] ??= <int>{}).add(dayNumber);
        }
      }
    }

    return {
      for (final entry in dayNumbersByShotId.entries) entry.key: entry.value.toList()..sort(),
    };
  }

  /// [dayId]'s own computed timelines (ADR 0015, as amended), one chain per live slot, joined
  /// into a single [OcptShootingDayTimelines] — or null while the day has no live slot to chain at
  /// all. Delegates to [planSnapshot].
  OcptShootingDayTimelines? timelinesOfDay(String dayId) => planSnapshot?.timelinesOfDay(dayId);

  /// Day [dayId]'s own whole call (ADR 0018): one `OcptDayConvocation` per person and per uncast
  /// role linked to any of its live slots, empty while [dayId] names no day with a live slot at
  /// all (or while [planSnapshot] itself is null). Delegates to [planSnapshot].
  List<OcptDayConvocation> convocationsOfDay(String dayId) =>
      planSnapshot?.convocationsOfDay(dayId) ?? const [];

  /// Day [dayId]'s own earliest arrival — the minimum **resolved** start over its live slots — or
  /// null while it has no live slot at all. Delegates to [planSnapshot].
  int? dayArrivalMinute(String dayId) => planSnapshot?.dayArrivalMinute(dayId);

  /// [dayId]'s own computed sun and twilight times (ADR 0016), or null while its first live slot
  /// has no location, or that location has no coordinates pinned yet. Delegates to [planSnapshot].
  OcptSunTimes? sunTimesOfDay(String dayId) => planSnapshot?.sunTimesOfDay(dayId);

  /// Every alert day [dayId] itself raises, in the order `ocptComputeScheduleAlerts` returned them
  /// (hard before soft), empty while it raises none — what every day-level alert indicator of the
  /// mode reads. Delegates to [planSnapshot].
  List<OcptScheduleAlert> alertsOfDay(String dayId) =>
      planSnapshot?.alertsByDayId[dayId] ?? const [];

  /// [dayId]'s own first live slot's location, or null while it has none — what a day's own tint
  /// (`ocptScheduleDayLocationTint`) and its inspector's own "Locations" line are read off.
  /// Delegates to [planSnapshot].
  OcptLocation? firstLocationOfDay(String dayId) => planSnapshot?.firstLocationOfDay(dayId);

  /// [targetId]'s current value for `field` — a pending edit still sitting in [pendingFieldEdits],
  /// or [storedValue] (the entity's own value, read off the call site) otherwise.
  String fieldValueOf(String targetId, OcptScheduleField field, String storedValue) =>
      pendingFieldEdits[(targetId, field)] ?? storedValue;

  /// Class constructor
  ///
  /// Not `const`, unlike the other modes' own states: [planSnapshot] is a `late final` field, which
  /// a const constructor cannot carry. Nothing ever built this state as a constant.
  OcptScheduleState({
    required this.isLoading,
    required this.title,
    required this.snapshot,
    required this.shotListSnapshots,
    required this.episodes,
    required this.locations,
    required this.roles,
    required this.people,
    required this.elements,
    required this.roleCandidates,
    required this.minimumRestMinutes,
    required this.selectedDayId,
    required this.selectedBlockId,
    required this.centreView,
    required this.agendaMode,
    required this.agendaColorMode,
    required this.firstWeekday,
    required this.agendaAnchorDate,
    required this.isListPanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.selectedShotId,
    required this.pendingFieldEdits,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.pageSetup,
    required this.ioNotice,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
    required this.projectPackagePendingExport,
    required this.projectPackageNotice,
  });

  /// Init class constructor
  OcptScheduleState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      shotListSnapshots = const [],
      episodes = const [],
      locations = const [],
      roles = const [],
      people = const [],
      elements = const [],
      roleCandidates = const [],
      minimumRestMinutes = null,
      selectedDayId = null,
      selectedBlockId = null,
      centreView = OcptScheduleCentreView.day,
      agendaMode = OcptScheduleAgendaMode.strip,
      agendaColorMode = OcptScheduleAgendaColorMode.location,
      firstWeekday = OcptFirstWeekday.monday,
      agendaAnchorDate = DateTime.now(),
      isListPanelVisible = true,
      rightDockTab = null,
      lastRightDockTab = OcptScheduleRightDockTab.inspector,
      selectedShotId = null,
      pendingFieldEdits = const {},
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      pageSetup = const OcptPageSetup.standard(),
      ioNotice = null,
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot], [shotListSnapshots] and [episodes] are only replaced when a new one is given,
  /// exactly as `OcptBreakdownState.snapshot`. [selectedDayId], [selectedBlockId], [rightDockTab],
  /// [selectedShotId] and [minimumRestMinutes] all legitimately go back to null while the mode is
  /// alive, so each has its own clear flag. [pendingFieldEdits] is always replaced wholesale — the
  /// caller (the bloc's own field-edit handler) always computes the full next map.
  @override
  OcptScheduleState copyWith({
    bool? isLoading,
    String? title,
    OcptScheduleSnapshot? snapshot,
    List<OcptShotListSnapshot>? shotListSnapshots,
    List<OcptEpisode>? episodes,
    List<OcptLocation>? locations,
    List<OcptRole>? roles,
    List<OcptPerson>? people,
    List<OcptElement>? elements,
    List<OcptRoleCandidate>? roleCandidates,
    int? minimumRestMinutes,
    bool clearMinimumRestMinutes = false,
    String? selectedDayId,
    bool clearSelectedDayId = false,
    String? selectedBlockId,
    bool clearSelectedBlockId = false,
    OcptScheduleCentreView? centreView,
    OcptScheduleAgendaMode? agendaMode,
    OcptScheduleAgendaColorMode? agendaColorMode,
    OcptFirstWeekday? firstWeekday,
    DateTime? agendaAnchorDate,
    bool? isListPanelVisible,
    OcptScheduleRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptScheduleRightDockTab? lastRightDockTab,
    String? selectedShotId,
    bool clearSelectedShotId = false,
    Map<OcptSchedulePendingFieldKey, String>? pendingFieldEdits,
    double? leftDockFraction,
    double? rightDockFraction,
    OcptPageSetup? pageSetup,
    OcptScheduleIoNotice? ioNotice,
    bool clearIoNotice = false,
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
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
  }) => OcptScheduleState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? this.snapshot,
    shotListSnapshots: shotListSnapshots ?? this.shotListSnapshots,
    episodes: episodes ?? this.episodes,
    locations: locations ?? this.locations,
    roles: roles ?? this.roles,
    people: people ?? this.people,
    elements: elements ?? this.elements,
    roleCandidates: roleCandidates ?? this.roleCandidates,
    minimumRestMinutes: clearMinimumRestMinutes
        ? null
        : (minimumRestMinutes ?? this.minimumRestMinutes),
    selectedDayId: clearSelectedDayId ? null : (selectedDayId ?? this.selectedDayId),
    selectedBlockId: clearSelectedBlockId ? null : (selectedBlockId ?? this.selectedBlockId),
    centreView: centreView ?? this.centreView,
    agendaMode: agendaMode ?? this.agendaMode,
    agendaColorMode: agendaColorMode ?? this.agendaColorMode,
    firstWeekday: firstWeekday ?? this.firstWeekday,
    agendaAnchorDate: agendaAnchorDate ?? this.agendaAnchorDate,
    isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    selectedShotId: clearSelectedShotId ? null : (selectedShotId ?? this.selectedShotId),
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    pageSetup: pageSetup ?? this.pageSetup,
    ioNotice: clearIoNotice ? null : (ioNotice ?? this.ioNotice),
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
    projectPackagePendingExport: clearProjectPackagePendingExport
        ? null
        : (projectPackagePendingExport ?? this.projectPackagePendingExport),
    projectPackageNotice: clearProjectPackageNotice
        ? null
        : (projectPackageNotice ?? this.projectPackageNotice),
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

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptScheduleState copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
  }) => copyWith(
    projectPackagePendingExport: projectPackagePendingExport,
    clearProjectPackagePendingExport: clearProjectPackagePendingExport,
    projectPackageNotice: projectPackageNotice,
    clearProjectPackageNotice: clearProjectPackageNotice,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    snapshot,
    shotListSnapshots,
    episodes,
    locations,
    roles,
    people,
    elements,
    roleCandidates,
    minimumRestMinutes,
    selectedDayId,
    selectedBlockId,
    centreView,
    agendaMode,
    agendaColorMode,
    firstWeekday,
    agendaAnchorDate,
    isListPanelVisible,
    rightDockTab,
    lastRightDockTab,
    selectedShotId,
    pendingFieldEdits,
    leftDockFraction,
    rightDockFraction,
    pageSetup,
    ioNotice,
  ];
}
