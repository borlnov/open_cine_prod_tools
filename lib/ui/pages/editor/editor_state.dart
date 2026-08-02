// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_current_scene_index.dart';

/// A request, produced by `OcptEditorBloc`, for the page to move the editor caret to
/// [charOffset].
///
/// [id] increases with every request, so the page's bloc listener can tell a fresh request apart
/// from the one it already applied even when two consecutive requests target the same offset
/// (e.g. clicking the same scene twice).
class OcptEditorJumpRequest extends Equatable {
  /// The character offset, in the source text, to move the caret to.
  final int charOffset;

  /// The monotonically increasing identifier of this request.
  final int id;

  /// Class constructor
  const OcptEditorJumpRequest({required this.charOffset, required this.id});

  /// Object properties
  @override
  List<Object?> get props => [charOffset, id];
}

/// The kind of transient notice `OcptEditorIoNotice` carries, one per export/import outcome.
enum OcptEditorIoNoticeKind {
  /// The screenplay was successfully exported to a `.fountain` file.
  exportSucceeded,

  /// Exporting the screenplay to a `.fountain` file failed.
  exportFailed,

  /// The screenplay text was successfully replaced by an imported `.fountain` file.
  importSucceeded,

  /// Importing a `.fountain` file to replace the screenplay text failed.
  importFailed,

  /// The screenplay was successfully exported to a PDF file.
  pdfExportSucceeded,

  /// Exporting the screenplay to a PDF file failed.
  pdfExportFailed,
}

/// A transient notice, produced by `OcptEditorBloc`, reporting the outcome of an export or an
/// import-and-replace, shown as a SnackBar then dismissed.
class OcptEditorIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptEditorIoNoticeKind kind;

  /// The path the screenplay was exported to, only set when [kind] is
  /// [OcptEditorIoNoticeKind.exportSucceeded] or [OcptEditorIoNoticeKind.pdfExportSucceeded].
  final String? path;

  /// Class constructor
  const OcptEditorIoNotice({required this.kind, this.path});

  /// Object properties
  @override
  List<Object?> get props => [kind, path];
}

/// The state of `OcptEditorBloc`.
///
/// Mixes in [MixinOcptProjectVersionsState], the slice every production mode shares: the project's
/// versions belong to the project, not to the screenplay, so the four fields the `Versions` dock
/// tab reads come from there rather than being declared here.
class OcptEditorState extends BlocStateForMixin<OcptEditorState>
    with MixinOcptProjectVersionsState<OcptEditorState> {
  /// Whether the screenplay is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The full source text as last reported to the bloc (the text controller owns the live text).
  final String text;

  /// The last parsed document, or null while nothing has been parsed yet.
  ///
  /// The document lags [text] by the parse debounce delay: it always corresponds to some recent
  /// value of [text], not necessarily the latest one.
  final FountainDocument? document;

  /// Whether [text] holds changes that haven't been saved to the project database yet.
  final bool isDirty;

  /// Whether a save is currently in progress.
  final bool isSaving;

  /// The time of the last successful save, or null if nothing was saved in this session yet.
  final DateTime? lastSavedAt;

  /// Whether the last save attempt failed; shown as a transient SnackBar then dismissed.
  final bool hasSaveError;

  /// The 0-based source line the editor caret is currently on.
  final int currentLine;

  /// Whether the scene panel is shown.
  final bool isScenePanelVisible;

  /// The right dock's currently active tab, or null if the dock is closed.
  ///
  /// Session-local, like [isScenePanelVisible]: it always starts on [OcptEditorRightDockTab
  /// .preview] when the editor opens, then only changes through explicit user action (the
  /// toolbar's tab buttons, or the dock's own close button) or the raw/styled mode-switch
  /// transition documented on [autoClosedRightDockTab].
  final OcptEditorRightDockTab? rightDockTab;

  /// The tab the right dock last showed, kept even while the dock is closed so the toolbar's own
  /// right dock toggle can reopen it where the user left it.
  ///
  /// Unlike [rightDockTab], this never goes back to null: it starts on
  /// [OcptEditorRightDockTab.preview] and then follows every tab the user selects, whether that
  /// selection opened the dock, switched it or closed it. Reopening the dock still applies the
  /// styled mode's own rule on top of it (that mode has no preview tab at all), see
  /// `OcptEditorBloc`'s right dock toggle handler.
  final OcptEditorRightDockTab lastRightDockTab;

  /// The tab a raw → styled mode switch auto-closed while it was the active [rightDockTab],
  /// restored the next time the mode switches back to raw (and this cleared back to null in the
  /// process).
  ///
  /// Any explicit user action on the dock (selecting a tab from the toolbar, or closing the dock
  /// by hand) also clears this immediately, so a dock the user closed on purpose never reopens
  /// behind their back on a later mode switch.
  final OcptEditorRightDockTab? autoClosedRightDockTab;

  /// The left (scenes) dock's width, as a fraction of the editing row's width.
  ///
  /// Persisted through `OcptPropertiesManager.editorLeftDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
  final double leftDockFraction;

  /// The right (preview / syntax) dock's width, as a fraction of the editing row's width.
  ///
  /// Persisted through `OcptPropertiesManager.editorRightDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
  final double rightDockFraction;

  /// The current editing mode: the styled block editor or the raw text source.
  ///
  /// Persisted through `OcptPropertiesManager.editorMode`, loaded once on entry and updated on
  /// every toggle.
  final OcptEditorMode mode;

  /// The page setup (format and margins) of the project, driving the preview's and the styled
  /// page editor's layout metrics.
  final OcptPageSetup pageSetup;

  /// Whether the "Word-like" page simulation (distinct paper sheets, real page size and
  /// margins) is enabled, in both the raw preview and the styled editor.
  ///
  /// Persisted through `OcptPropertiesManager.isPageSimulationEnabled`, loaded once on entry and
  /// updated on every toggle; on by default.
  final bool isPageSimulationEnabled;

  /// Whether the styled editor shows every scene heading's number (explicit or computed) in its
  /// left gutter.
  ///
  /// Persisted through `OcptPropertiesManager.styledSceneNumbersVisible`, loaded once on entry and
  /// updated on every toggle; on by default.
  final bool areStyledSceneNumbersVisible;

  /// The pending caret jump request, or null if none was ever made.
  ///
  /// The page keeps track of the last [OcptEditorJumpRequest.id] it applied, so this doesn't
  /// need to be cleared once handled.
  final OcptEditorJumpRequest? jumpRequest;

  /// The transient export/import outcome currently shown as a SnackBar, or null if none is.
  final OcptEditorIoNotice? ioNotice;

  /// The at-a-glance counters (page/scene/character/word/sign counts) shown in the editor's
  /// status bar, computed from [document] at [pageSetup]'s metrics.
  ///
  /// Lags [document] slightly further behind [text] than the parse debounce alone: recomputing it
  /// paginates the whole screenplay, which is too heavy to run on every parse tick while typing
  /// continuously (see `OcptEditorBloc`'s own statistics debounce).
  final FountainScriptStatistics statistics;

  /// The [FountainSceneStatistics] of the scene at [currentSceneIndex], or null while nothing is
  /// parsed yet or the caret precedes every scene.
  ///
  /// Unlike [currentSceneIndex] itself, this doesn't recompute on every caret move: composing the
  /// whole document to derive [FountainSceneStatistics.pageEighths] is the same "too heavy for
  /// every frame" cost [statistics] already documents, so `OcptEditorBloc` only recomputes this on
  /// its own 150 ms parse debounce, or when a caret move actually lands on a different scene.
  final FountainSceneStatistics? sceneStatistics;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersions}
  @override
  final List<OcptProjectVersion> projectVersions;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.previewedVersionId}
  @override
  final String? previewedVersionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingDeletionId}
  @override
  final String? versionPendingDeletionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersionNotice}
  @override
  final OcptProjectVersionNoticeKind? projectVersionNotice;

  /// The scene headings of [document], in source order (empty while nothing is parsed).
  List<FountainSceneHeading> get scenes => document?.scenes ?? const [];

  /// The index, in [scenes], of the scene containing [currentLine], or null while nothing is
  /// parsed yet or the caret precedes every scene. Cheap to derive live from state already
  /// tracked, unlike [sceneStatistics].
  int? get currentSceneIndex => currentSceneIndexFor(scenes, currentLine);

  /// Class constructor
  const OcptEditorState({
    required this.isLoading,
    required this.title,
    required this.text,
    required this.document,
    required this.isDirty,
    required this.isSaving,
    required this.lastSavedAt,
    required this.hasSaveError,
    required this.currentLine,
    required this.isScenePanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.autoClosedRightDockTab,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.mode,
    required this.pageSetup,
    required this.isPageSimulationEnabled,
    required this.areStyledSceneNumbersVisible,
    required this.jumpRequest,
    required this.ioNotice,
    required this.statistics,
    required this.sceneStatistics,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.versionPendingDeletionId,
    required this.projectVersionNotice,
  });

  /// Init class constructor
  const OcptEditorState.init()
    : isLoading = true,
      title = "",
      text = "",
      document = null,
      isDirty = false,
      isSaving = false,
      lastSavedAt = null,
      hasSaveError = false,
      currentLine = 0,
      isScenePanelVisible = true,
      rightDockTab = OcptEditorRightDockTab.preview,
      lastRightDockTab = OcptEditorRightDockTab.preview,
      autoClosedRightDockTab = null,
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      mode = OcptEditorMode.styled,
      pageSetup = const OcptPageSetup.standard(),
      isPageSimulationEnabled = true,
      areStyledSceneNumbersVisible = true,
      jumpRequest = null,
      ioNotice = null,
      statistics = FountainScriptStatistics.empty,
      sceneStatistics = null,
      projectVersions = const [],
      previewedVersionId = null,
      versionPendingDeletionId = null,
      projectVersionNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [document], [lastSavedAt], [jumpRequest] and [statistics] are only replaced when a new value
  /// is given: they never go back to null (or, for [statistics], to
  /// [FountainScriptStatistics.empty]) once set, so no clear flag is needed for them. [ioNotice]
  /// is only replaced when a new one is given or [clearIoNotice] is true, exactly like
  /// `OcptHomeState`'s own `error` field. [rightDockTab], [autoClosedRightDockTab] and
  /// [sceneStatistics] follow the same idiom as [ioNotice], each with its own clear flag
  /// ([clearRightDockTab], [clearAutoClosedRightDockTab], [clearSceneStatistics]): all three
  /// legitimately go back to null during the editor's lifetime (closing the dock, restoring it on
  /// a mode switch, the caret moving back before every scene), so the "never goes back to null"
  /// shortcut used above doesn't apply to them.
  @override
  OcptEditorState copyWith({
    bool? isLoading,
    String? title,
    String? text,
    FountainDocument? document,
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSavedAt,
    bool? hasSaveError,
    int? currentLine,
    bool? isScenePanelVisible,
    OcptEditorRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptEditorRightDockTab? lastRightDockTab,
    OcptEditorRightDockTab? autoClosedRightDockTab,
    bool clearAutoClosedRightDockTab = false,
    double? leftDockFraction,
    double? rightDockFraction,
    OcptEditorMode? mode,
    OcptPageSetup? pageSetup,
    bool? isPageSimulationEnabled,
    bool? areStyledSceneNumbersVisible,
    OcptEditorJumpRequest? jumpRequest,
    OcptEditorIoNotice? ioNotice,
    bool clearIoNotice = false,
    FountainScriptStatistics? statistics,
    FountainSceneStatistics? sceneStatistics,
    bool clearSceneStatistics = false,
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
  }) => OcptEditorState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    text: text ?? this.text,
    document: document ?? this.document,
    isDirty: isDirty ?? this.isDirty,
    isSaving: isSaving ?? this.isSaving,
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    hasSaveError: hasSaveError ?? this.hasSaveError,
    currentLine: currentLine ?? this.currentLine,
    isScenePanelVisible: isScenePanelVisible ?? this.isScenePanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    autoClosedRightDockTab: clearAutoClosedRightDockTab
        ? null
        : (autoClosedRightDockTab ?? this.autoClosedRightDockTab),
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    mode: mode ?? this.mode,
    pageSetup: pageSetup ?? this.pageSetup,
    isPageSimulationEnabled: isPageSimulationEnabled ?? this.isPageSimulationEnabled,
    areStyledSceneNumbersVisible: areStyledSceneNumbersVisible ?? this.areStyledSceneNumbersVisible,
    jumpRequest: jumpRequest ?? this.jumpRequest,
    ioNotice: clearIoNotice ? null : (ioNotice ?? this.ioNotice),
    statistics: statistics ?? this.statistics,
    sceneStatistics: clearSceneStatistics ? null : (sceneStatistics ?? this.sceneStatistics),
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId: clearPreviewedVersionId
        ? null
        : (previewedVersionId ?? this.previewedVersionId),
    versionPendingDeletionId: clearVersionPendingDeletionId
        ? null
        : (versionPendingDeletionId ?? this.versionPendingDeletionId),
    projectVersionNotice: clearProjectVersionNotice
        ? null
        : (projectVersionNotice ?? this.projectVersionNotice),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptEditorState copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
  }) => copyWith(
    projectVersions: projectVersions,
    previewedVersionId: previewedVersionId,
    clearPreviewedVersionId: clearPreviewedVersionId,
    versionPendingDeletionId: versionPendingDeletionId,
    clearVersionPendingDeletionId: clearVersionPendingDeletionId,
    projectVersionNotice: projectVersionNotice,
    clearProjectVersionNotice: clearProjectVersionNotice,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    text,
    document,
    isDirty,
    isSaving,
    lastSavedAt,
    hasSaveError,
    currentLine,
    isScenePanelVisible,
    rightDockTab,
    lastRightDockTab,
    autoClosedRightDockTab,
    leftDockFraction,
    rightDockFraction,
    mode,
    pageSetup,
    isPageSimulationEnabled,
    areStyledSceneNumbersVisible,
    jumpRequest,
    ioNotice,
    statistics,
    sceneStatistics,
  ];
}
