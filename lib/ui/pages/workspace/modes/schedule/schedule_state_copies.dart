// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';

/// The named copies of an `OcptScheduleState`: each one is a change the bloc makes, spelled out
/// with every field the change affects.
extension OcptScheduleStateCopiesExtension on OcptScheduleState {
  /// Copies this state with the selected shot cleared, which moves the selection with the cause
  /// [OcptScheduleSelectionCause.shotCleared].
  OcptScheduleState copyWithShotCleared() => copyWith(
    forceSelectedShotIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptScheduleSelectionCause.shotCleared,
  );

  /// Copies this state with the data a reload read, each given part replacing its counterpart.
  ///
  /// The selected day goes when [isDayDropped], the selected block when [isBlockDropped], and
  /// dropping either moves the selection with the cause [OcptScheduleSelectionCause.dropped].
  OcptScheduleState copyWithReloadedSchedule({
    required OcptScheduleSnapshot? snapshot,
    required List<OcptShotListSnapshot>? shotListSnapshots,
    required List<OcptEpisode>? episodes,
    required bool isDayDropped,
    required bool isBlockDropped,
  }) {
    final isSelectionDropped = isDayDropped || isBlockDropped;
    return copyWith(
      snapshot: snapshot,
      shotListSnapshots: shotListSnapshots,
      episodes: episodes,
      forceSelectedDayIdValue: isDayDropped,
      forceSelectedBlockIdValue: isBlockDropped,
      selectionEpoch: isSelectionDropped ? selectionEpoch + 1 : null,
      selectionCause: isSelectionDropped ? OcptScheduleSelectionCause.dropped : null,
    );
  }

  /// Copies this state as loaded when no project is open: the preferences restored, no snapshot,
  /// no version previewed and nothing selected.
  OcptScheduleState copyToLoadedWithoutProject({
    required double leftDockFraction,
    required double rightDockFraction,
    required OcptScheduleRightDockTab lastRightDockTab,
    required OcptFirstWeekday firstWeekday,
  }) => copyWith(
    isLoading: false,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    lastRightDockTab: lastRightDockTab,
    firstWeekday: firstWeekday,
    forcePreviewedVersionIdValue: true,
    forceSelectedDayIdValue: true,
    forceSelectedBlockIdValue: true,
    forceSelectedShotIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptScheduleSelectionCause.load,
  );

  /// Copies this state as loaded from the open project: everything read from it, the preferences
  /// restored, [defaultDayId] selected and no block or shot selected.
  ///
  /// The previewed version id goes back to null when [previewedVersion] is, the minimum rest when
  /// [minimumRestMinutes] is, and the selected day when [defaultDayId] is. The agenda is anchored
  /// on [agendaAnchorDate].
  OcptScheduleState copyToLoaded({
    required String title,
    required OcptProjectVersion? previewedVersion,
    required OcptScheduleSnapshot snapshot,
    required List<OcptShotListSnapshot> shotListSnapshots,
    required List<OcptEpisode> episodes,
    required List<OcptLocation> locations,
    required List<OcptRole> roles,
    required List<OcptPerson> people,
    required List<OcptElement> elements,
    required List<OcptRoleCandidate> roleCandidates,
    required OcptPageSetup pageSetup,
    required int? minimumRestMinutes,
    required DateTime agendaAnchorDate,
    required String? defaultDayId,
    required double leftDockFraction,
    required double rightDockFraction,
    required OcptScheduleRightDockTab lastRightDockTab,
    required OcptFirstWeekday firstWeekday,
  }) => copyWith(
    isLoading: false,
    title: title,
    previewedVersionId: previewedVersion?.id,
    forcePreviewedVersionIdValue: previewedVersion == null,
    snapshot: snapshot,
    shotListSnapshots: shotListSnapshots,
    episodes: episodes,
    locations: locations,
    roles: roles,
    people: people,
    elements: elements,
    roleCandidates: roleCandidates,
    pageSetup: pageSetup,
    minimumRestMinutes: minimumRestMinutes,
    forceMinimumRestMinutesValue: minimumRestMinutes == null,
    agendaAnchorDate: agendaAnchorDate,
    selectedDayId: defaultDayId,
    forceSelectedDayIdValue: defaultDayId == null,
    forceSelectedBlockIdValue: true,
    forceSelectedShotIdValue: true,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    lastRightDockTab: lastRightDockTab,
    firstWeekday: firstWeekday,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptScheduleSelectionCause.load,
  );

  /// Copies this state with the list panel's visibility flipped.
  OcptScheduleState copyWithListPanelToggled() => copyWith(isListPanelVisible: !isListPanelVisible);

  /// Copies this state with [tab] as the last right dock tab, and the dock closed when
  /// [isAlreadyActive] or showing [tab] otherwise.
  OcptScheduleState copyWithRightDockTabSelected({
    required OcptScheduleRightDockTab tab,
    required bool isAlreadyActive,
  }) => copyWith(
    rightDockTab: isAlreadyActive ? null : tab,
    forceRightDockTabValue: isAlreadyActive,
    lastRightDockTab: tab,
  );

  /// Copies this state with the right dock closed.
  OcptScheduleState copyWithRightDockClosed() => copyWith(forceRightDockTabValue: true);

  /// Copies this state with the right dock opened on the last tab it showed.
  OcptScheduleState copyWithRightDockReopened() => copyWith(rightDockTab: lastRightDockTab);

  /// Copies this state with [left] and [right] as the dock fractions.
  ///
  /// A null fraction keeps the current one.
  OcptScheduleState copyWithDockFractions({required double? left, required double? right}) =>
      copyWith(leftDockFraction: left, rightDockFraction: right);

  /// Copies this state with day [dayId] selected alone: no block and no shot.
  OcptScheduleState copyWithSelectedDay({required String dayId}) => copyWith(
    selectedDayId: dayId,
    forceSelectedBlockIdValue: true,
    forceSelectedShotIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptScheduleSelectionCause.day,
  );

  /// Copies this state with block [blockId] of day [dayId] selected, the inspector showing and no
  /// shot selected.
  OcptScheduleState copyWithSelectedBlock({required String dayId, required String blockId}) =>
      copyWith(
        selectedDayId: dayId,
        selectedBlockId: blockId,
        forceSelectedShotIdValue: true,
        rightDockTab: OcptScheduleRightDockTab.inspector,
        lastRightDockTab: OcptScheduleRightDockTab.inspector,
        selectionEpoch: selectionEpoch + 1,
        selectionCause: OcptScheduleSelectionCause.block,
      );

  /// Copies this state with shot [shotId] selected, the inspector showing and no block selected.
  OcptScheduleState copyWithSelectedShot({required String shotId}) => copyWith(
    selectedShotId: shotId,
    forceSelectedBlockIdValue: true,
    rightDockTab: OcptScheduleRightDockTab.inspector,
    lastRightDockTab: OcptScheduleRightDockTab.inspector,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptScheduleSelectionCause.shot,
  );

  /// Copies this state with day [dayId], just added, selected alone.
  OcptScheduleState copyWithAddedDay({required String dayId}) => copyWith(
    selectedDayId: dayId,
    forceSelectedBlockIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptScheduleSelectionCause.dayAdded,
  );

  /// Copies this state with [view] as the centre view.
  OcptScheduleState copyWithCentreView({required OcptScheduleCentreView view}) =>
      copyWith(centreView: view);

  /// Copies this state with [mode] as the agenda's presentation.
  OcptScheduleState copyWithAgendaMode({required OcptScheduleAgendaMode mode}) =>
      copyWith(agendaMode: mode);

  /// Copies this state with [mode] as the fact the agenda tints a day with.
  OcptScheduleState copyWithAgendaColorMode({required OcptScheduleAgendaColorMode mode}) =>
      copyWith(agendaColorMode: mode);

  /// Copies this state with the agenda paged to [date].
  OcptScheduleState copyWithAgendaAnchorDate({required DateTime date}) =>
      copyWith(agendaAnchorDate: date);
}
