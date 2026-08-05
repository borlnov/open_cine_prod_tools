// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_search.dart';

/// The state of `OcptBreakdownBloc`.
///
/// Selecting a target or a scene, hiding a legend key, switching [centreView] and typing into
/// [searchQuery] all write nothing to the project database. [pendingElementFieldEdits] and
/// [pendingSceneNotesEdits] are the pending field edits this state
/// carries, the selected target's own free-text fields and the selected scene's own breakdown
/// notes riding the debounce every other mode's `pending…FieldEdits` map does — see
/// `OcptBreakdownBloc`'s own doc comment. [pendingTagAnchor] and [pendingTagRange] are likewise
/// ephemeral and write nothing on their own: the range interaction they drive only touches the
/// database once the popover it opens answers with a link or an element creation.
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

  /// Which of the two views (script or recap) the mode's centre currently shows, toggled by the
  /// header's own `Script`/`Recap` switch (`OcptBreakdownHeader`).
  ///
  /// A reading choice for the pass in progress, exactly like [hiddenLegendKeys]: **not**
  /// persisted, so a project reopened days later always starts back on the script view rather than
  /// wherever a previous session happened to leave the centre.
  final OcptBreakdownCentreView centreView;

  /// The header's own search field, as typed — filters the recap's rows, never its scene columns.
  ///
  /// Typing into it while [centreView] is [OcptBreakdownCentreView.script] switches the centre to
  /// the recap in the same emitted state (`OcptBreakdownBloc._onSearchQueryChanged`); clearing it
  /// back to empty afterward does **not** switch back to the script view — see that handler's own
  /// doc comment. A reading choice for the pass in progress, exactly like [centreView]: **not**
  /// persisted.
  final String searchQuery;

  /// The id of the scene currently selected, whose heading the script view highlights, or null
  /// while none is.
  final String? selectedSceneId;

  /// The legend keys currently hidden from the script view's own highlighting
  /// (`OcptBreakdownCategoryLegend`). A reading aid for the pass in progress alone: **not**
  /// persisted, unlike the two dock fractions below — a category silently hidden three launches
  /// later would read as a bug rather than a deliberate choice.
  final Set<OcptBreakdownLegendKey> hiddenLegendKeys;

  /// The `(kind, id)` of the currently selected target, or null while none is — raw, exactly as
  /// [selectedSceneId] is; [selectedTarget] is its resolved counterpart, looked up against
  /// [snapshot].
  final (OcptBreakdownTargetKind, String)? selectedTargetRef;

  /// Whether the left (scene) dock is shown.
  final bool isListPanelVisible;

  /// The right dock's currently active tab, or null if the dock is closed.
  final OcptBreakdownRightDockTab? rightDockTab;

  /// The tab the toolbar's right-dock toggle reopens a closed dock on: the last one explicitly
  /// selected (`OcptBreakdownRightDockTabSelectedEvent`), mirroring
  /// `OcptShotListState.lastRightDockTab`.
  ///
  /// Persisted through `OcptPropertiesManager.breakdownLastRightDockTab`, loaded once on entry.
  /// Selecting a target additionally forces both this and [rightDockTab] to
  /// [OcptBreakdownRightDockTab.inspector], since that hand-off — landing on the target's own sheet
  /// without a second gesture — is the whole point of the selection.
  final OcptBreakdownRightDockTab lastRightDockTab;

  /// Whether the inline confirmation of "remove this target's tags from the selected scene" is
  /// shown, in place of `OcptBreakdownTargetInspector`'s own trailing action.
  ///
  /// A single flag rather than an id-keyed pending map (`OcptProjectVersionsPanel`'s own idiom for
  /// the very same inline-confirmation shape): the inspector only ever asks this about the
  /// currently selected target, so there is only ever one question to ask at a time. Reset to false
  /// by every handler that changes the selection or reloads the snapshot, so a stale confirmation
  /// never survives to a different target's sheet.
  final bool isTagRemovalPending;

  /// A typed field of the selected target's own sheet still sitting in the field-edit debounce,
  /// keyed by the element's id and which `OcptElementField` it is — `subCategory`, `quantity` or
  /// `notes`, the only three the target inspector ever edits — mirroring
  /// `OcptResourcesState.pendingElementFieldEdits`. [elementFieldValueOf] is what a field reads
  /// instead of the element's own stored value while an edit is pending here.
  final Map<(String, OcptElementField), String> pendingElementFieldEdits;

  /// A scene's own breakdown notes still sitting in the field-edit debounce, keyed by the scene's
  /// id, mirroring [pendingElementFieldEdits] over the same debounce timer.
  /// [sceneNotesValueOf] is what the scene inspector's notes field reads instead of the scene's own
  /// stored value while an edit is pending here.
  final Map<String, String> pendingSceneNotesEdits;

  /// The first word clicked of a range not yet closed, or null while none is open — the script
  /// view's own cue to mark that word as pending. Cleared the moment the range closes (successfully
  /// or by falling into another scene, which simply replaces it) or is cancelled outright.
  final OcptBreakdownPendingTagAnchor? pendingTagAnchor;

  /// A range just closed by a second click, awaiting the popover's own answer, or null while none
  /// is — the script view's cue to anchor `OcptBreakdownTagPopover` under the word that closed it.
  final OcptBreakdownPendingTagRange? pendingTagRange;

  /// Whether the popover's last write (a link or an element creation) was refused — the overlap, or
  /// a preview database that slipped through — and a transient notice should tell the user rather
  /// than the popover silently closing. Reset the moment it has been shown once.
  final bool hasTagWriteError;

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

  /// `snapshot.doneSceneCount`, the header's own progress label and bar.
  int get doneSceneCount => snapshot?.doneSceneCount ?? 0;

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

  /// The target [selectedTargetRef] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot]) — the script view's tagged words and the right
  /// dock's target inspector both read this rather than [selectedTargetRef] itself.
  OcptBreakdownTarget? get selectedTarget {
    final selectedTargetRef = this.selectedTargetRef;
    if (selectedTargetRef == null) {
      return null;
    }

    final (kind, id) = selectedTargetRef;
    for (final target in targets) {
      if (target.kind == kind && target.id == id) {
        return target;
      }
    }

    return null;
  }

  /// The whole `elements` catalogue of [snapshot] (empty while nothing is loaded).
  List<OcptElement> get elements => snapshot?.elements ?? const [];

  /// The whole address book of [snapshot] (empty while nothing is loaded), offered by the target
  /// inspector's owner and who-brings-it pickers.
  List<OcptPerson> get people => snapshot?.people ?? const [];

  /// The whole cast of [snapshot] (empty while nothing is loaded), one of the three raw catalogues
  /// [searchCandidates] flattens for the tag popover.
  List<OcptRole> get roles => snapshot?.roles ?? const [];

  /// The whole set catalogue of [snapshot] (empty while nothing is loaded), the sibling of [roles].
  List<OcptSet> get sets => snapshot?.sets ?? const [];

  /// The candidates the tag popover searches, built once from [snapshot] — empty while nothing is
  /// loaded, exactly as every other snapshot-derived getter here.
  List<OcptBreakdownSearchCandidate> get searchCandidates {
    final snapshot = this.snapshot;
    return snapshot == null ? const [] : ocptBreakdownSearchCandidatesOf(snapshot);
  }

  /// The raw `elements` row [selectedTarget] resolves to, or null while [selectedTarget] is null,
  /// names something other than an element, or — like [selectedTarget] itself — has disappeared
  /// from a freshly loaded [snapshot]. What the target inspector's Status, Category and Details
  /// sections read: [selectedTarget] itself deliberately carries only the two fields the script
  /// view's highlighting and the recap need.
  OcptElement? get selectedElement {
    final selectedTarget = this.selectedTarget;
    if (selectedTarget == null || selectedTarget.kind != OcptBreakdownTargetKind.element) {
      return null;
    }

    for (final element in elements) {
      if (element.id == selectedTarget.id) {
        return element;
      }
    }

    return null;
  }

  /// [elementId]'s current value for `field` — a pending edit still sitting in
  /// [pendingElementFieldEdits], or [storedValue] (the element's own value, read off [selectedElement]
  /// at the call site) otherwise, exactly as `OcptShotListState`/`OcptResourcesState` resolve their
  /// own pending field edits.
  String elementFieldValueOf(String elementId, OcptElementField field, String storedValue) =>
      pendingElementFieldEdits[(elementId, field)] ?? storedValue;

  /// [sceneId]'s current value for its own breakdown notes — a pending edit still sitting in
  /// [pendingSceneNotesEdits], or [storedValue] (the scene's own value, read off `selectedScene` at
  /// the call site) otherwise, mirroring [elementFieldValueOf].
  String sceneNotesValueOf(String sceneId, String storedValue) =>
      pendingSceneNotesEdits[sceneId] ?? storedValue;

  /// Class constructor
  const OcptBreakdownState({
    required this.isLoading,
    required this.title,
    required this.screenplayText,
    required this.pageSetup,
    required this.snapshot,
    required this.centreView,
    required this.searchQuery,
    required this.selectedSceneId,
    required this.hiddenLegendKeys,
    required this.selectedTargetRef,
    required this.isListPanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.isTagRemovalPending,
    required this.pendingElementFieldEdits,
    required this.pendingSceneNotesEdits,
    required this.pendingTagAnchor,
    required this.pendingTagRange,
    required this.hasTagWriteError,
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
      centreView = OcptBreakdownCentreView.script,
      searchQuery = "",
      selectedSceneId = null,
      hiddenLegendKeys = const {},
      selectedTargetRef = null,
      isListPanelVisible = true,
      rightDockTab = null,
      lastRightDockTab = OcptBreakdownRightDockTab.inspector,
      isTagRemovalPending = false,
      pendingElementFieldEdits = const {},
      pendingSceneNotesEdits = const {},
      pendingTagAnchor = null,
      pendingTagRange = null,
      hasTagWriteError = false,
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
  /// it needs no clear flag. [selectedSceneId], [selectedTargetRef], [rightDockTab],
  /// [pendingTagAnchor] and [pendingTagRange] all legitimately go back to null while the mode is
  /// alive (a fresh load, a selection dropped, the dock closed, an anchor replaced or a range
  /// resolved), so each has its own clear flag instead. [hiddenLegendKeys],
  /// [pendingElementFieldEdits] and [pendingSceneNotesEdits] are each replaced wholesale rather
  /// than merged — the caller (the bloc's own legend and field-edit handlers) always computes the
  /// full next map or set. [searchQuery] needs no clear flag either: an empty string is already a
  /// perfectly valid value for it (the field cleared), so `searchQuery: ""` is passed like any other
  /// value rather than through a `clear…` flag.
  @override
  OcptBreakdownState copyWith({
    bool? isLoading,
    String? title,
    String? screenplayText,
    OcptPageSetup? pageSetup,
    OcptBreakdownSnapshot? snapshot,
    OcptBreakdownCentreView? centreView,
    String? searchQuery,
    String? selectedSceneId,
    bool clearSelectedSceneId = false,
    Set<OcptBreakdownLegendKey>? hiddenLegendKeys,
    (OcptBreakdownTargetKind, String)? selectedTargetRef,
    bool clearSelectedTargetRef = false,
    bool? isListPanelVisible,
    OcptBreakdownRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptBreakdownRightDockTab? lastRightDockTab,
    bool? isTagRemovalPending,
    Map<(String, OcptElementField), String>? pendingElementFieldEdits,
    Map<String, String>? pendingSceneNotesEdits,
    OcptBreakdownPendingTagAnchor? pendingTagAnchor,
    bool clearPendingTagAnchor = false,
    OcptBreakdownPendingTagRange? pendingTagRange,
    bool clearPendingTagRange = false,
    bool? hasTagWriteError,
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
    centreView: centreView ?? this.centreView,
    searchQuery: searchQuery ?? this.searchQuery,
    selectedSceneId: clearSelectedSceneId ? null : (selectedSceneId ?? this.selectedSceneId),
    hiddenLegendKeys: hiddenLegendKeys ?? this.hiddenLegendKeys,
    selectedTargetRef: clearSelectedTargetRef ? null : (selectedTargetRef ?? this.selectedTargetRef),
    isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    isTagRemovalPending: isTagRemovalPending ?? this.isTagRemovalPending,
    pendingElementFieldEdits: pendingElementFieldEdits ?? this.pendingElementFieldEdits,
    pendingSceneNotesEdits: pendingSceneNotesEdits ?? this.pendingSceneNotesEdits,
    pendingTagAnchor: clearPendingTagAnchor ? null : (pendingTagAnchor ?? this.pendingTagAnchor),
    pendingTagRange: clearPendingTagRange ? null : (pendingTagRange ?? this.pendingTagRange),
    hasTagWriteError: hasTagWriteError ?? this.hasTagWriteError,
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
    centreView,
    searchQuery,
    selectedSceneId,
    hiddenLegendKeys,
    selectedTargetRef,
    isListPanelVisible,
    rightDockTab,
    lastRightDockTab,
    isTagRemovalPending,
    pendingElementFieldEdits,
    pendingSceneNotesEdits,
    pendingTagAnchor,
    pendingTagRange,
    hasTagWriteError,
    leftDockFraction,
    rightDockFraction,
  ];
}
