// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
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
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_sun_times.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_unplaced_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state_copies.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_unplaced_group.dart';

/// The state of `OcptScheduleBloc`.
///
/// [selectedShotId] writes nothing to the project database on its own: it is a selection, exactly
/// like [selectedBlockId] beside it, only ever naming which shot's own read-out the inspector
/// currently shows. The free-text edits typed and not yet written belong to `OcptScheduleDayBloc`.
class OcptScheduleState extends BlocStateForMixin<OcptScheduleState>
    with
        MixinOcptProjectVersionsState<OcptScheduleState>,
        MixinOcptProjectPackageState<OcptScheduleState>,
        MixinOcptModeState<OcptScheduleState> {
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

  /// {@macro open_cine_prod_tools.MixinOcptModeState.reloadEpoch}
  @override
  final int reloadEpoch;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.selectionEpoch}
  @override
  final int selectionEpoch;

  /// What moved the selection the last time [selectionEpoch] advanced: a view clears different
  /// things for different gestures (see [OcptScheduleSelectionCause]).
  final OcptScheduleSelectionCause selectionCause;

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

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExportTarget}
  @override
  final OcptProjectPackageTarget? projectPackagePendingExportTarget;

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
    return selectedDayId == null ? const [] : (snapshot?.slotsByDayId[selectedDayId] ?? const []);
  }

  /// [selectedDayId]'s own live blocks — its timetable — in `sortKey` order.
  List<OcptShootingDayBlock> get selectedDayBlocks {
    final selectedDayId = this.selectedDayId;
    return selectedDayId == null ? const [] : (snapshot?.blocksByDayId[selectedDayId] ?? const []);
  }

  /// [selectedDayId]'s own live events, ordered by [OcptShootingDayEvent.minute] then by
  /// `sortKey` — see `OcptScheduleSnapshot.eventsByDayId`.
  List<OcptShootingDayEvent> get selectedDayEvents {
    final selectedDayId = this.selectedDayId;
    return selectedDayId == null ? const [] : (snapshot?.eventsByDayId[selectedDayId] ?? const []);
  }

  /// The event [eventId] of the selected day, or null while it names none of
  /// [selectedDayEvents] — what the day view's and the day inspector's own event label/notes fields
  /// read their stored value off, there being no per-event map to keep in step with a fresh
  /// snapshot.
  OcptShootingDayEvent? selectedDayEventOf(String eventId) {
    for (final event in selectedDayEvents) {
      if (event.id == eventId) {
        return event;
      }
    }
    return null;
  }

  /// The guest attendance [guestId] among the guests of the selected day's [selectedDaySlots], or
  /// null while it names no live guest of the selected day — what a slot card's own guest
  /// reason/notes fields read their stored value off.
  OcptShootingSlotGuest? selectedDayGuestOf(String guestId) {
    for (final slot in selectedDaySlots) {
      for (final guest in slot.guests) {
        if (guest.id == guestId) {
          return guest;
        }
      }
    }
    return null;
  }

  /// The hour a freshly created event of day [dayId] is first given — that day's own earliest
  /// resolved slot start ([dayArrivalMinute]) when it has one, or 09:00 otherwise. Only ever a
  /// **starting point**: the row's own minute field immediately lets the user correct it, so this
  /// is never a claim about when anything actually happens on the day.
  int newEventMinuteOf(String dayId) => dayArrivalMinute(dayId) ?? _defaultDayEventFallbackMinute;

  /// The hour a freshly created day event falls back to when its day has no live slot yet to read
  /// an arrival off — see [newEventMinuteOf].
  static const int _defaultDayEventFallbackMinute = 9 * 60;

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
            displaySceneNumber: sequence is OcptSceneShotSequence
                ? sequence.displaySceneNumber
                : null,
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

    for (final entry
        in snapshot?.blocksByDayId.entries ??
            const <MapEntry<String, List<OcptShootingDayBlock>>>[]) {
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
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.pageSetup,
    required this.reloadEpoch,
    required this.selectionEpoch,
    required this.selectionCause,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
    required this.projectPackagePendingExport,
    required this.projectPackageNotice,
    required this.projectPackagePendingExportTarget,
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
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      pageSetup = const OcptPageSetup.standard(),
      reloadEpoch = 0,
      selectionEpoch = 0,
      selectionCause = OcptScheduleSelectionCause.none,
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null,
      projectPackagePendingExportTarget = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot], [shotListSnapshots] and [episodes] are only replaced when a new one is given,
  /// exactly as `OcptBreakdownState.snapshot`. [selectedDayId], [selectedBlockId], [rightDockTab],
  /// [selectedShotId] and [minimumRestMinutes] all legitimately go back to null while the mode is
  /// alive, so each has its own force flag.
  ///
  /// **[reloadEpoch] moves by itself** whenever a copy replaces any of the data read from the
  /// project database ([snapshot], [shotListSnapshots], [episodes], [locations], [roles], [people],
  /// [elements], [roleCandidates], [minimumRestMinutes], [pageSetup]), so no handler can read the
  /// data again and forget to tell the views. An explicit [reloadEpoch] wins, for an emit that
  /// moves it without replacing anything.
  @override
  OcptScheduleState copyWith({
    bool? isLoading,
    String? title,
    OcptScheduleSnapshot? snapshot,
    bool forceSnapshotValue = false,
    List<OcptShotListSnapshot>? shotListSnapshots,
    List<OcptEpisode>? episodes,
    List<OcptLocation>? locations,
    List<OcptRole>? roles,
    List<OcptPerson>? people,
    List<OcptElement>? elements,
    List<OcptRoleCandidate>? roleCandidates,
    int? minimumRestMinutes,
    bool forceMinimumRestMinutesValue = false,
    String? selectedDayId,
    bool forceSelectedDayIdValue = false,
    String? selectedBlockId,
    bool forceSelectedBlockIdValue = false,
    OcptScheduleCentreView? centreView,
    OcptScheduleAgendaMode? agendaMode,
    OcptScheduleAgendaColorMode? agendaColorMode,
    OcptFirstWeekday? firstWeekday,
    DateTime? agendaAnchorDate,
    bool? isListPanelVisible,
    OcptScheduleRightDockTab? rightDockTab,
    bool forceRightDockTabValue = false,
    OcptScheduleRightDockTab? lastRightDockTab,
    String? selectedShotId,
    bool forceSelectedShotIdValue = false,
    double? leftDockFraction,
    double? rightDockFraction,
    OcptPageSetup? pageSetup,
    int? reloadEpoch,
    int? selectionEpoch,
    OcptScheduleSelectionCause? selectionCause,
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool forcePreviewedVersionIdValue = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool forceWorkingCopyValue = false,
    String? versionPendingDeletionId,
    bool forceVersionPendingDeletionIdValue = false,
    String? versionPendingRestoreId,
    bool forceVersionPendingRestoreIdValue = false,
    String? versionPendingRenameId,
    bool forceVersionPendingRenameIdValue = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool forceProjectVersionNoticeValue = false,
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
    OcptProjectPackageTarget? projectPackagePendingExportTarget,
    bool forceProjectPackagePendingExportTargetValue = false,
  }) => OcptScheduleState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? (forceSnapshotValue ? null : this.snapshot),
    shotListSnapshots: shotListSnapshots ?? this.shotListSnapshots,
    episodes: episodes ?? this.episodes,
    locations: locations ?? this.locations,
    roles: roles ?? this.roles,
    people: people ?? this.people,
    elements: elements ?? this.elements,
    roleCandidates: roleCandidates ?? this.roleCandidates,
    minimumRestMinutes:
        minimumRestMinutes ?? (forceMinimumRestMinutesValue ? null : this.minimumRestMinutes),
    selectedDayId: selectedDayId ?? (forceSelectedDayIdValue ? null : this.selectedDayId),
    selectedBlockId: selectedBlockId ?? (forceSelectedBlockIdValue ? null : this.selectedBlockId),
    centreView: centreView ?? this.centreView,
    agendaMode: agendaMode ?? this.agendaMode,
    agendaColorMode: agendaColorMode ?? this.agendaColorMode,
    firstWeekday: firstWeekday ?? this.firstWeekday,
    agendaAnchorDate: agendaAnchorDate ?? this.agendaAnchorDate,
    isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
    rightDockTab: rightDockTab ?? (forceRightDockTabValue ? null : this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    selectedShotId: selectedShotId ?? (forceSelectedShotIdValue ? null : this.selectedShotId),
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    pageSetup: pageSetup ?? this.pageSetup,
    reloadEpoch:
        reloadEpoch ??
        (_isDataReplacedBy(
              snapshot: snapshot,
              shotListSnapshots: shotListSnapshots,
              episodes: episodes,
              locations: locations,
              roles: roles,
              people: people,
              elements: elements,
              roleCandidates: roleCandidates,
              minimumRestMinutes: minimumRestMinutes,
              forceMinimumRestMinutesValue: forceMinimumRestMinutesValue,
              pageSetup: pageSetup,
            )
            ? this.reloadEpoch + 1
            : this.reloadEpoch),
    selectionEpoch: selectionEpoch ?? this.selectionEpoch,
    selectionCause: selectionCause ?? this.selectionCause,
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId:
        previewedVersionId ?? (forcePreviewedVersionIdValue ? null : this.previewedVersionId),
    workingCopy: workingCopy ?? (forceWorkingCopyValue ? null : this.workingCopy),
    versionPendingDeletionId:
        versionPendingDeletionId ??
        (forceVersionPendingDeletionIdValue ? null : this.versionPendingDeletionId),
    versionPendingRestoreId:
        versionPendingRestoreId ??
        (forceVersionPendingRestoreIdValue ? null : this.versionPendingRestoreId),
    versionPendingRenameId:
        versionPendingRenameId ??
        (forceVersionPendingRenameIdValue ? null : this.versionPendingRenameId),
    projectVersionNotice:
        projectVersionNotice ?? (forceProjectVersionNoticeValue ? null : this.projectVersionNotice),
    projectPackagePendingExport:
        projectPackagePendingExport ??
        (forceProjectPackagePendingExportValue ? null : this.projectPackagePendingExport),
    projectPackageNotice:
        projectPackageNotice ?? (forceProjectPackageNoticeValue ? null : this.projectPackageNotice),
    projectPackagePendingExportTarget:
        projectPackagePendingExportTarget ??
        (forceProjectPackagePendingExportTargetValue
            ? null
            : this.projectPackagePendingExportTarget),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  /// Whether any of the given pieces of data read from the project database is a new value, i.e.
  /// whether a copy made with them re-reads the data (see [copyWith]).
  static bool _isDataReplacedBy({
    required Object? snapshot,
    required Object? shotListSnapshots,
    required Object? episodes,
    required Object? locations,
    required Object? roles,
    required Object? people,
    required Object? elements,
    required Object? roleCandidates,
    required Object? minimumRestMinutes,
    required bool forceMinimumRestMinutesValue,
    required Object? pageSetup,
  }) =>
      snapshot != null ||
      shotListSnapshots != null ||
      episodes != null ||
      locations != null ||
      roles != null ||
      people != null ||
      elements != null ||
      roleCandidates != null ||
      minimumRestMinutes != null ||
      forceMinimumRestMinutesValue ||
      pageSetup != null;

  @override
  OcptScheduleState copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool forcePreviewedVersionIdValue = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool forceWorkingCopyValue = false,
    String? versionPendingDeletionId,
    bool forceVersionPendingDeletionIdValue = false,
    String? versionPendingRestoreId,
    bool forceVersionPendingRestoreIdValue = false,
    String? versionPendingRenameId,
    bool forceVersionPendingRenameIdValue = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool forceProjectVersionNoticeValue = false,
  }) => copyWith(
    projectVersions: projectVersions,
    previewedVersionId: previewedVersionId,
    forcePreviewedVersionIdValue: forcePreviewedVersionIdValue,
    workingCopy: workingCopy,
    forceWorkingCopyValue: forceWorkingCopyValue,
    versionPendingDeletionId: versionPendingDeletionId,
    forceVersionPendingDeletionIdValue: forceVersionPendingDeletionIdValue,
    versionPendingRestoreId: versionPendingRestoreId,
    forceVersionPendingRestoreIdValue: forceVersionPendingRestoreIdValue,
    versionPendingRenameId: versionPendingRenameId,
    forceVersionPendingRenameIdValue: forceVersionPendingRenameIdValue,
    projectVersionNotice: projectVersionNotice,
    forceProjectVersionNoticeValue: forceProjectVersionNoticeValue,
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptScheduleState copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
    OcptProjectPackageTarget? projectPackagePendingExportTarget,
    bool forceProjectPackagePendingExportTargetValue = false,
  }) => copyWith(
    projectPackagePendingExport: projectPackagePendingExport,
    forceProjectPackagePendingExportValue: forceProjectPackagePendingExportValue,
    projectPackageNotice: projectPackageNotice,
    forceProjectPackageNoticeValue: forceProjectPackageNoticeValue,
    projectPackagePendingExportTarget: projectPackagePendingExportTarget,
    forceProjectPackagePendingExportTargetValue: forceProjectPackagePendingExportTargetValue,
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
    leftDockFraction,
    rightDockFraction,
    pageSetup,
    reloadEpoch,
    selectionEpoch,
    selectionCause,
  ];
}
