// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_current_scene_index.dart';
import 'package:spell_kit/spell_kit.dart';

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

/// The editor's live find/replace state — one search, kept in the bloc rather than in either
/// editing surface, which is what lets it survive a raw ⇄ styled mode toggle (the plan's own
/// M4 decision).
class OcptEditorSearchState extends Equatable {
  /// Whether the find/replace bar is open at all.
  final bool isOpen;

  /// Whether the replace row is unfolded under the find row.
  final bool isReplaceRowOpen;

  /// The text currently searched for.
  final String query;

  /// The text a match is replaced by.
  final String replacement;

  /// Whether the search is case-sensitive.
  final bool isCaseSensitive;

  /// Whether the search only matches whole words.
  final bool isWholeWord;

  /// The number of matches the mounted editing surface last reported.
  ///
  /// Computed over what that surface actually shows — the raw source text, or a styled node's
  /// display text — so the count can legitimately differ between the two modes for a query
  /// holding markup (a forcing marker, a `#N#` tag, `*`/`_` emphasis): a search shows what the
  /// user can see, not the underlying Fountain source the styled mode never displays.
  final int matchCount;

  /// The 0-based index, among [matchCount] matches, of the current one; null while there is none.
  final int? currentMatchIndex;

  /// The id of the last request to (re)focus and select the find field, bumped on every "open".
  ///
  /// The same idiom as [OcptEditorJumpRequest.id]: the bar remembers the last one it applied, so
  /// re-opening an already-open bar (or unfolding its replace row through Ctrl+H) still refocuses
  /// the find field even though [isOpen] itself doesn't change value.
  final int focusRequestId;

  /// Class constructor
  const OcptEditorSearchState({
    required this.isOpen,
    required this.isReplaceRowOpen,
    required this.query,
    required this.replacement,
    required this.isCaseSensitive,
    required this.isWholeWord,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.focusRequestId,
  });

  /// Init class constructor
  const OcptEditorSearchState.init()
    : isOpen = false,
      isReplaceRowOpen = false,
      query = "",
      replacement = "",
      isCaseSensitive = false,
      isWholeWord = false,
      matchCount = 0,
      currentMatchIndex = null,
      focusRequestId = 0;

  /// Returns a copy of this state with the given fields replaced.
  ///
  /// [currentMatchIndex] only goes back to null through [clearCurrentMatchIndex] — the "there is
  /// no match" state a plain `int?` field can't tell apart from "leave it as it is" on its own.
  OcptEditorSearchState copyWith({
    bool? isOpen,
    bool? isReplaceRowOpen,
    String? query,
    String? replacement,
    bool? isCaseSensitive,
    bool? isWholeWord,
    int? matchCount,
    int? currentMatchIndex,
    bool clearCurrentMatchIndex = false,
    int? focusRequestId,
  }) => OcptEditorSearchState(
    isOpen: isOpen ?? this.isOpen,
    isReplaceRowOpen: isReplaceRowOpen ?? this.isReplaceRowOpen,
    query: query ?? this.query,
    replacement: replacement ?? this.replacement,
    isCaseSensitive: isCaseSensitive ?? this.isCaseSensitive,
    isWholeWord: isWholeWord ?? this.isWholeWord,
    matchCount: matchCount ?? this.matchCount,
    currentMatchIndex: clearCurrentMatchIndex ? null : (currentMatchIndex ?? this.currentMatchIndex),
    focusRequestId: focusRequestId ?? this.focusRequestId,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    isOpen,
    isReplaceRowOpen,
    query,
    replacement,
    isCaseSensitive,
    isWholeWord,
    matchCount,
    currentMatchIndex,
    focusRequestId,
  ];
}

/// The kind of transient notice `OcptEditorIoNotice` carries, one per export/import outcome.
enum OcptEditorIoNoticeKind {
  /// The screenplay was successfully exported to a `.fountain` file.
  exportSucceeded,

  /// Exporting the screenplay to a `.fountain` file failed.
  exportFailed,

  /// The screenplay text was successfully replaced by an imported screenplay file.
  importSucceeded,

  /// Importing a screenplay file to replace the screenplay text failed while it was being written
  /// to the project: the file itself was read, so the screenplay on screen is the old one still.
  importFailed,

  /// The picked file could not be read as a screenplay at all, so nothing was replaced.
  ///
  /// Told apart from [importFailed] on purpose: this one names the file the user picked, which
  /// picking another one fixes, where the other names the project's own write failing.
  importUnreadable,

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
/// versions belong to the project, not to the screenplay, so the fields the `Versions` dock tab
/// reads come from there rather than being declared here.
class OcptEditorState extends BlocStateForMixin<OcptEditorState>
    with
        MixinOcptProjectVersionsState<OcptEditorState>,
        MixinOcptProjectPackageState<OcptEditorState> {
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

  /// Whether this machine wants the spell-check underlines shown, in either editing mode.
  ///
  /// Persisted through `OcptPropertiesManager.spellCheckVisible`, loaded once on entry and updated
  /// on every toggle; on by default. This is one of the two independent on/off switches
  /// (`docs/architecture/screenplay.md`) — the other is [screenplayLanguage] — and
  /// nothing is checked while either is off: `OcptEditorBloc` only loads a dictionary into
  /// `OcptSpellCheckManager` and only requests a check when both are satisfied.
  final bool isSpellCheckVisible;

  /// The language the open project's screenplays are written in, or null if nobody has said (or no
  /// project is open) — see [OcptScreenplayLanguage]'s own doc comment.
  ///
  /// Read from `OcptProjectsManager.loadCurrentProjectScreenplayLanguage` on entry and re-read
  /// whenever the project settings page might have changed it; this is the second of the two
  /// on/off switches (see [isSpellCheckVisible]'s own doc comment).
  final OcptScreenplayLanguage? screenplayLanguage;

  /// The misspelled ranges found in the raw mode's Fountain source text, document-absolute (the
  /// very offsets its `OcptEditorSearchTextController` paints in), reported by
  /// `OcptEditorBloc`'s debounced spell-check pass.
  ///
  /// Empty while spell-checking is off (either switch), while a project version is being
  /// previewed, or before the first pass has answered, or while the raw editing surface isn't the
  /// one mounted (`OcptEditorBloc._requestSpellCheck` only runs in raw mode, so nothing here would
  /// paint anyway — see that method's own doc comment).
  final List<SpellRange> rawSpellCheckRanges;

  /// The misspelled ranges found in the styled mode's checkable node texts, keyed by node id, each
  /// relative to that node's own display text — the exact addressing `SpellingAndGrammarStyler`
  /// wants, reported by `OcptEditorBloc`'s own debounced pass over whatever
  /// `OcptStyledEditorController.reportSpellCheckTexts` last handed it.
  ///
  /// Empty under the same three conditions [rawSpellCheckRanges] is, mirrored: spell-checking off
  /// (either switch), a project version being previewed, or before the first pass has answered. A
  /// node id this holds that no longer exists in the live document (a full rebuild since the ranges
  /// were computed) is simply ignored by the styled editor rather than reaching the styler.
  final Map<String, List<SpellRange>> styledSpellCheckRanges;

  /// The pending caret jump request, or null if none was ever made.
  ///
  /// The page keeps track of the last [OcptEditorJumpRequest.id] it applied, so this doesn't
  /// need to be cleared once handled.
  final OcptEditorJumpRequest? jumpRequest;

  /// The transient export/import outcome currently shown as a SnackBar, or null if none is.
  final OcptEditorIoNotice? ioNotice;

  /// The editor's find/replace state — see `OcptEditorSearchState`'s own doc comment for why it
  /// lives here rather than in either editing surface.
  final OcptEditorSearchState search;

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

  /// Whether the right dock's formatted-preview tab exists at all right now.
  ///
  /// Two states have no use for it, for the same reason: what the centre already shows *is* the
  /// formatted screenplay — the styled block editor, and the read-only preview a project version is
  /// shown through. `OcptEditorBloc` applies the same predicate to the mode it is about to switch
  /// to, through [isPreviewTabAvailableFor], so an open preview tab is auto-closed (and remembered)
  /// rather than left showing nothing.
  bool get isPreviewTabAvailable =>
      isPreviewTabAvailableFor(mode: mode, isReadOnly: isPreviewingVersion);

  /// The prospective form of [isPreviewTabAvailable]: whether the preview tab would exist in
  /// [mode], with [isReadOnly] telling whether a project version is being previewed.
  static bool isPreviewTabAvailableFor({
    required OcptEditorMode mode,
    required bool isReadOnly,
  }) => mode == OcptEditorMode.raw && !isReadOnly;

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
    required this.isSpellCheckVisible,
    required this.screenplayLanguage,
    required this.rawSpellCheckRanges,
    required this.styledSpellCheckRanges,
    required this.jumpRequest,
    required this.ioNotice,
    required this.search,
    required this.statistics,
    required this.sceneStatistics,
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
      isSpellCheckVisible = true,
      screenplayLanguage = null,
      rawSpellCheckRanges = const [],
      styledSpellCheckRanges = const {},
      jumpRequest = null,
      ioNotice = null,
      search = const OcptEditorSearchState.init(),
      statistics = FountainScriptStatistics.empty,
      sceneStatistics = null,
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
  /// [document], [lastSavedAt], [jumpRequest] and [statistics] are only replaced when a new value
  /// is given: they never go back to null (or, for [statistics], to
  /// [FountainScriptStatistics.empty]) once set, so no clear flag is needed for them. [ioNotice]
  /// is only replaced when a new one is given or [clearIoNotice] is true, exactly like
  /// `OcptHomeState`'s own `error` field. [rightDockTab], [autoClosedRightDockTab],
  /// [sceneStatistics] and [screenplayLanguage] follow the same idiom as [ioNotice], each with its
  /// own clear flag ([clearRightDockTab], [clearAutoClosedRightDockTab], [clearSceneStatistics],
  /// [clearScreenplayLanguage]): all four legitimately go back to null during the editor's
  /// lifetime (closing the dock, restoring it on a mode switch, the caret moving back before every
  /// scene, a project's language being unset), so the "never goes back to null" shortcut used
  /// above doesn't apply to them. [search] is replaced wholesale (through its own
  /// `OcptEditorSearchState.copyWith`), not flattened into this method's own parameter list.
  /// [rawSpellCheckRanges] and [styledSpellCheckRanges] need no clear flag despite legitimately
  /// going back to empty (spell-check turning off, a version preview starting): `const []`/`const
  /// {}` are themselves values, passed explicitly by the caller wanting that, rather than a state a
  /// plain `?? this.rawSpellCheckRanges` couldn't already distinguish from "leave it as it is".
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
    bool? isSpellCheckVisible,
    OcptScreenplayLanguage? screenplayLanguage,
    bool clearScreenplayLanguage = false,
    List<SpellRange>? rawSpellCheckRanges,
    Map<String, List<SpellRange>>? styledSpellCheckRanges,
    OcptEditorJumpRequest? jumpRequest,
    OcptEditorIoNotice? ioNotice,
    bool clearIoNotice = false,
    OcptEditorSearchState? search,
    FountainScriptStatistics? statistics,
    FountainSceneStatistics? sceneStatistics,
    bool clearSceneStatistics = false,
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
    isSpellCheckVisible: isSpellCheckVisible ?? this.isSpellCheckVisible,
    screenplayLanguage: clearScreenplayLanguage ? null : (screenplayLanguage ?? this.screenplayLanguage),
    rawSpellCheckRanges: rawSpellCheckRanges ?? this.rawSpellCheckRanges,
    styledSpellCheckRanges: styledSpellCheckRanges ?? this.styledSpellCheckRanges,
    jumpRequest: jumpRequest ?? this.jumpRequest,
    ioNotice: clearIoNotice ? null : (ioNotice ?? this.ioNotice),
    search: search ?? this.search,
    statistics: statistics ?? this.statistics,
    sceneStatistics: clearSceneStatistics ? null : (sceneStatistics ?? this.sceneStatistics),
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
    projectPackagePendingExport: clearProjectPackagePendingExport
        ? null
        : (projectPackagePendingExport ?? this.projectPackagePendingExport),
    projectPackageNotice: clearProjectPackageNotice
        ? null
        : (projectPackageNotice ?? this.projectPackageNotice),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptEditorState copyProjectVersionsState({
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
  OcptEditorState copyProjectPackageState({
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
    isSpellCheckVisible,
    screenplayLanguage,
    rawSpellCheckRanges,
    styledSpellCheckRanges,
    jumpRequest,
    ioNotice,
    search,
    statistics,
    sceneStatistics,
  ];
}
