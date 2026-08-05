// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// The state of `OcptBreakdownBloc`.
///
/// Unlike the resources or shot list modes' own state, this one carries no pending field edit of
/// any kind: this milestone's script view only reads, and nothing here writes to the project
/// database yet — see `OcptBreakdownBloc.flushPendingProjectWrites`'s own doc comment for what will
/// need one once the scene notes and the target inspector land.
class OcptBreakdownState extends BlocStateForMixin<OcptBreakdownState>
    with MixinOcptProjectVersionsState<OcptBreakdownState> {
  /// Whether the breakdown read is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The screenplay's Fountain text as last read, sliced scene by scene
  /// (`OcptBreakdownScene.charStart`/`charEnd`) by `OcptBreakdownScriptView` into what each scene's
  /// own sheet is built from.
  final String screenplayText;

  /// The page setup the script view is typeset with: the open project's own page format, paired
  /// with the app-wide margins preference, exactly as the shot list's own scenario coverage dialog
  /// pairs them. A version being previewed is laid out with the setup it was captured against
  /// instead (`OcptOpenProjectModel.previewedPageSetup`).
  final OcptPageSetup pageSetup;

  /// The whole breakdown read, as last loaded from the project database, or null while nothing has
  /// been read yet.
  final OcptBreakdownSnapshot? snapshot;

  /// The id of the scene currently selected, whose heading the script view highlights, or null
  /// while none is.
  final String? selectedSceneId;

  /// Whether the left (scene) dock is shown.
  final bool isListPanelVisible;

  /// The right dock's currently active tab, or null if the dock is closed.
  ///
  /// Only one tab exists to reopen ([OcptBreakdownRightDockTab.versions]), exactly as the resources
  /// mode's own right dock, so this mode keeps no "last tab" preference of its own.
  final OcptBreakdownRightDockTab? rightDockTab;

  /// The left (scene) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.breakdownLeftDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
  final double leftDockFraction;

  /// The right (versions) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.breakdownRightDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
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

  /// Every scene of [snapshot], in source order (empty while nothing is loaded).
  List<OcptBreakdownScene> get scenes => snapshot?.scenes ?? const [];

  /// Every tagged target of [snapshot] (empty while nothing is loaded).
  List<OcptBreakdownTarget> get targets => snapshot?.targets ?? const [];

  /// `snapshot.taggedTargetCount`, the status bar's first counter.
  int get taggedTargetCount => snapshot?.taggedTargetCount ?? 0;

  /// `snapshot.usedCategoryCount`, the status bar's second counter.
  int get usedCategoryCount => snapshot?.usedCategoryCount ?? 0;

  /// `snapshot.toFindCount`, the status bar's trailing counter.
  int get toFindCount => snapshot?.toFindCount ?? 0;

  /// The scene [selectedSceneId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot]).
  OcptBreakdownScene? get selectedScene {
    final selectedSceneId = this.selectedSceneId;
    if (selectedSceneId == null) {
      return null;
    }

    for (final scene in scenes) {
      if (scene.id == selectedSceneId) {
        return scene;
      }
    }

    return null;
  }

  /// Class constructor
  const OcptBreakdownState({
    required this.isLoading,
    required this.title,
    required this.screenplayText,
    required this.pageSetup,
    required this.snapshot,
    required this.selectedSceneId,
    required this.isListPanelVisible,
    required this.rightDockTab,
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
  OcptBreakdownState.init()
    : isLoading = true,
      title = "",
      screenplayText = "",
      pageSetup = const OcptPageSetup.standard(),
      snapshot = null,
      selectedSceneId = null,
      isListPanelVisible = true,
      rightDockTab = null,
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
  /// [snapshot] is only replaced when a new one is given: it never goes back to null once loaded, so
  /// it needs no clear flag. [selectedSceneId] and [rightDockTab] both legitimately go back to null
  /// while the mode is alive (a fresh load, the dock closed), so each has its own clear flag
  /// instead.
  @override
  OcptBreakdownState copyWith({
    bool? isLoading,
    String? title,
    String? screenplayText,
    OcptPageSetup? pageSetup,
    OcptBreakdownSnapshot? snapshot,
    String? selectedSceneId,
    bool clearSelectedSceneId = false,
    bool? isListPanelVisible,
    OcptBreakdownRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
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
  }) => OcptBreakdownState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    screenplayText: screenplayText ?? this.screenplayText,
    pageSetup: pageSetup ?? this.pageSetup,
    snapshot: snapshot ?? this.snapshot,
    selectedSceneId: clearSelectedSceneId ? null : (selectedSceneId ?? this.selectedSceneId),
    isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId: clearPreviewedVersionId
        ? null
        : (previewedVersionId ?? this.previewedVersionId),
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
  OcptBreakdownState copyProjectVersionsState({
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
    screenplayText,
    pageSetup,
    snapshot,
    selectedSceneId,
    isListPanelVisible,
    rightDockTab,
    leftDockFraction,
    rightDockFraction,
  ];
}
