// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// The state of `OcptShotListBloc`.
///
/// Unlike the screenplay editor's own state, this one carries no dirty/saving pair: the shot list
/// is authored field by field rather than as one document, and every write goes straight to the
/// project database, so there is never an unsaved shot list to flush.
class OcptShotListState extends BlocStateForMixin<OcptShotListState> {
  /// Whether the shot list is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole shot list as last read from the project database, or null while nothing has been
  /// loaded yet.
  final OcptShotListSnapshot? snapshot;

  /// The [OcptShotSequence.id] of the sequence currently selected, or null while none is (an
  /// empty screenplay has no sequence to select in the first place).
  final String? selectedSequenceId;

  /// The id of the shot currently selected, or null while none is.
  ///
  /// Always a shot of [selectedSequence] while both are set: selecting a shot selects its
  /// sequence too, and selecting another sequence clears the shot.
  final String? selectedShotId;

  /// Whether the left (sequences) dock is shown.
  final bool isSequencePanelVisible;

  /// The right dock's currently active tab, or null if the dock is closed.
  final OcptShotListRightDockTab? rightDockTab;

  /// The tab the right dock last showed, kept even while the dock is closed so the toolbar's own
  /// right dock toggle can reopen it where the user left it.
  ///
  /// Unlike [rightDockTab] this never goes back to null, and unlike the screenplay editor's own
  /// equivalent it is persisted, through `OcptPropertiesManager.shotListLastRightDockTab`.
  final OcptShotListRightDockTab lastRightDockTab;

  /// The left (sequences) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.shotListLeftDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
  final double leftDockFraction;

  /// The right (inspector) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.shotListRightDockFraction`, loaded once on entry
  /// and updated (debounced to the end of a drag, never per-frame) on every resize.
  final double rightDockFraction;

  /// The optional table columns currently shown, out of every [OcptShotListColumn].
  ///
  /// Persisted through `OcptPropertiesManager.shotListVisibleColumns`, loaded once on entry and
  /// updated on every toggle of the `Columns ▾` menu.
  final Set<OcptShotListColumn> visibleColumns;

  /// Whether the last write to the project database failed; shown as a transient SnackBar then
  /// dismissed.
  final bool hasWriteError;

  /// Every sequence of [snapshot], in display order (empty while nothing is loaded).
  List<OcptShotSequence> get sequences => snapshot?.sequences ?? const [];

  /// The sequence [selectedSequenceId] identifies, or null if none is selected (or the selected
  /// one disappeared from a freshly loaded [snapshot]).
  OcptShotSequence? get selectedSequence {
    final selectedSequenceId = this.selectedSequenceId;
    if (selectedSequenceId == null) {
      return null;
    }

    for (final sequence in sequences) {
      if (sequence.id == selectedSequenceId) {
        return sequence;
      }
    }

    return null;
  }

  /// The shot [selectedShotId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot]).
  OcptShot? get selectedShot {
    final selectedShotId = this.selectedShotId;
    return selectedShotId == null ? null : snapshot?.shotsById[selectedShotId];
  }

  /// The total number of shots across every sequence, orphan group included.
  int get totalShotCount => snapshot?.totalShotCount ?? 0;

  /// Class constructor
  const OcptShotListState({
    required this.isLoading,
    required this.title,
    required this.snapshot,
    required this.selectedSequenceId,
    required this.selectedShotId,
    required this.isSequencePanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.visibleColumns,
    required this.hasWriteError,
  });

  /// Init class constructor
  OcptShotListState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      selectedSequenceId = null,
      selectedShotId = null,
      isSequencePanelVisible = true,
      rightDockTab = null,
      lastRightDockTab = OcptShotListRightDockTab.inspector,
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      visibleColumns = OcptShotListColumn.defaultVisibleColumns,
      hasWriteError = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot] is only replaced when a new one is given: it never goes back to null once loaded,
  /// so it needs no clear flag. [selectedSequenceId], [selectedShotId] and [rightDockTab] all
  /// legitimately go back to null while the mode is alive (nothing selected any more, the dock
  /// closed), so each has its own clear flag instead.
  @override
  OcptShotListState copyWith({
    bool? isLoading,
    String? title,
    OcptShotListSnapshot? snapshot,
    String? selectedSequenceId,
    bool clearSelectedSequenceId = false,
    String? selectedShotId,
    bool clearSelectedShotId = false,
    bool? isSequencePanelVisible,
    OcptShotListRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptShotListRightDockTab? lastRightDockTab,
    double? leftDockFraction,
    double? rightDockFraction,
    Set<OcptShotListColumn>? visibleColumns,
    bool? hasWriteError,
  }) => OcptShotListState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? this.snapshot,
    selectedSequenceId: clearSelectedSequenceId
        ? null
        : (selectedSequenceId ?? this.selectedSequenceId),
    selectedShotId: clearSelectedShotId ? null : (selectedShotId ?? this.selectedShotId),
    isSequencePanelVisible: isSequencePanelVisible ?? this.isSequencePanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    visibleColumns: visibleColumns ?? this.visibleColumns,
    hasWriteError: hasWriteError ?? this.hasWriteError,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    snapshot,
    selectedSequenceId,
    selectedShotId,
    isSequencePanelVisible,
    rightDockTab,
    lastRightDockTab,
    leftDockFraction,
    rightDockFraction,
    visibleColumns,
    hasWriteError,
  ];
}
