// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search_candidate.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_suggestions.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// The state of `OcptBreakdownBloc`.
///
/// Selecting a target or a scene, hiding a legend key, switching [centreView] and typing into
/// [searchQuery] all write nothing to the project database. What is typed into the inspector's
/// fields and not yet written lives in `OcptBreakdownInspectorState`, and the range the script view
/// is tagging in `OcptBreakdownTaggingState`.
class OcptBreakdownState extends BlocStateForMixin<OcptBreakdownState>
    with
        MixinOcptProjectVersionsState<OcptBreakdownState>,
        MixinOcptProjectPackageState<OcptBreakdownState>,
        MixinOcptModeState<OcptBreakdownState> {
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

  /// [selectedTarget]'s own suggested occurrences — passages elsewhere in the screenplay that read
  /// like one of its tags but are not tagged themselves (`ocptBreakdownSuggestionsOf`), offered by
  /// the target inspector's own "Suggested occurrences" section. Empty while nothing is loaded or
  /// no target is selected.
  ///
  /// A **stored** field rather than a getter over [snapshot], unlike [searchCandidates] and every
  /// other derived read here: answering it means folding every scene of the screenplay rune by
  /// rune, which on a feature-length one costs tens of milliseconds — far too much for something
  /// the mode reads on every rebuild, and this mode rebuilds on every keystroke into a notes field.
  /// [copyWith] is what computes it, and only when one of the three things it derives from
  /// ([snapshot], [screenplayText] and [selectedTargetRef]) actually changes, so the cost is paid
  /// once per selection change or snapshot reload and no handler can forget to refresh it.
  final List<OcptBreakdownSuggestion> selectedTargetSuggestions;

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

  /// {@macro open_cine_prod_tools.MixinOcptModeState.reloadEpoch}
  @override
  final int reloadEpoch;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.selectionEpoch}
  @override
  final int selectionEpoch;

  /// What moved the selection the last time [selectionEpoch] advanced.
  final OcptBreakdownSelectionCause selectionCause;

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

  /// `snapshot.needsCheckTagCount`, the status bar's own "N to check" counter.
  int get needsCheckTagCount => snapshot?.needsCheckTagCount ?? 0;

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

  /// Every orphaned-role alert found in [roles] (ADR 0030, decision 4) — what the mode-level
  /// compact banner is built from. No service work of its own: [roles] is already loaded for
  /// [searchCandidates].
  List<OcptRemovedRoleAlert> get orphanedRoleAlerts => OcptRemovedRoleAlert.buildAll(roles);

  /// Every name-collision alert found in [roles] (ADR 0030, decision 2), sorted stably — the
  /// compact banner's other half, mirroring `OcptResourcesState.roleCollisionAlerts`.
  List<OcptRoleCollisionAlert> get roleCollisionAlerts => OcptRoleCollisionAlert.buildAll(roles);

  /// The whole set catalogue of [snapshot] (empty while nothing is loaded), the sibling of [roles].
  List<OcptSet> get sets => snapshot?.sets ?? const [];

  /// The whole location catalogue of [snapshot] (empty while nothing is loaded) — what
  /// `ocptSceneSetSuggestionOf` reads to answer what a scene's heading suggests, and what the tag
  /// popover offers as the places a set it creates may go into.
  List<OcptLocation> get locations => snapshot?.locations ?? const [];

  /// The name of every live location of [snapshot], keyed by id — what names the place each of
  /// [sets] belongs to (`ocptBreakdownSetLabel`). Empty while nothing is loaded.
  Map<String, String> get locationNameById => snapshot?.locationNameById ?? const {};

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
    required this.selectedTargetSuggestions,
    required this.isListPanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.leftDockFraction,
    required this.rightDockFraction,
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
      selectedTargetSuggestions = const [],
      isListPanelVisible = true,
      rightDockTab = null,
      lastRightDockTab = OcptBreakdownRightDockTab.inspector,
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      reloadEpoch = 0,
      selectionEpoch = 0,
      selectionCause = OcptBreakdownSelectionCause.none,
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
  /// [snapshot] is only replaced when a new one is given: it never goes back to null once loaded,
  /// so it needs no force flag. [selectedSceneId], [selectedTargetRef] and [rightDockTab] all
  /// legitimately go back to null while the mode is alive (a fresh load, a selection dropped, the
  /// dock closed), so each has its own force flag instead. [hiddenLegendKeys] is replaced wholesale
  /// rather than merged — the caller (the bloc's own legend handlers) always computes the full next
  /// set. [searchQuery] needs no force flag either: an empty string is already a perfectly valid value for it (the field cleared), so
  /// `searchQuery: ""` is passed like any other value rather than through a `clear…` flag.
  ///
  /// [selectedTargetSuggestions] is the one field this recomputes rather than carries over, and it
  /// does so only when one of the three things it derives from ([snapshot], [screenplayText] and
  /// [selectedTargetRef]) has actually changed — see that field for why it is stored rather than
  /// derived on read. The first two are compared by identity, so a reloaded snapshot recomputes
  /// even when the project's tags happen to have come back exactly the same.
  ///
  /// **[reloadEpoch] moves by itself** whenever a copy replaces any of the data read from the
  /// project database ([snapshot], [screenplayText], [pageSetup]), so no handler can read the data
  /// again and forget to tell the views. An explicit [reloadEpoch] wins, for an emit that moves it
  /// without replacing anything.
  @override
  OcptBreakdownState copyWith({
    bool? isLoading,
    String? title,
    String? screenplayText,
    OcptPageSetup? pageSetup,
    OcptBreakdownSnapshot? snapshot,
    bool forceSnapshotValue = false,
    OcptBreakdownCentreView? centreView,
    String? searchQuery,
    String? selectedSceneId,
    bool forceSelectedSceneIdValue = false,
    Set<OcptBreakdownLegendKey>? hiddenLegendKeys,
    (OcptBreakdownTargetKind, String)? selectedTargetRef,
    bool forceSelectedTargetRefValue = false,
    bool? isListPanelVisible,
    OcptBreakdownRightDockTab? rightDockTab,
    bool forceRightDockTabValue = false,
    OcptBreakdownRightDockTab? lastRightDockTab,
    double? leftDockFraction,
    double? rightDockFraction,
    int? reloadEpoch,
    int? selectionEpoch,
    OcptBreakdownSelectionCause? selectionCause,
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
  }) {
    final nextSnapshot = snapshot ?? (forceSnapshotValue ? null : this.snapshot);
    final nextScreenplayText = screenplayText ?? this.screenplayText;
    final nextSelectedTargetRef =
        selectedTargetRef ?? (forceSelectedTargetRefValue ? null : this.selectedTargetRef);
    final keepsSuggestions =
        identical(nextSnapshot, this.snapshot) &&
        identical(nextScreenplayText, this.screenplayText) &&
        nextSelectedTargetRef == this.selectedTargetRef;

    return OcptBreakdownState(
      isLoading: isLoading ?? this.isLoading,
      title: title ?? this.title,
      screenplayText: nextScreenplayText,
      pageSetup: pageSetup ?? this.pageSetup,
      snapshot: nextSnapshot,
      centreView: centreView ?? this.centreView,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSceneId: selectedSceneId ?? (forceSelectedSceneIdValue ? null : this.selectedSceneId),
      hiddenLegendKeys: hiddenLegendKeys ?? this.hiddenLegendKeys,
      selectedTargetRef: nextSelectedTargetRef,
      selectedTargetSuggestions: keepsSuggestions
          ? selectedTargetSuggestions
          : _suggestionsOf(
              snapshot: nextSnapshot,
              screenplayText: nextScreenplayText,
              selectedTargetRef: nextSelectedTargetRef,
            ),
      isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
      rightDockTab: rightDockTab ?? (forceRightDockTabValue ? null : this.rightDockTab),
      lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
      leftDockFraction: leftDockFraction ?? this.leftDockFraction,
      rightDockFraction: rightDockFraction ?? this.rightDockFraction,
      reloadEpoch:
          reloadEpoch ??
          (snapshot != null || screenplayText != null || pageSetup != null
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
          projectVersionNotice ??
          (forceProjectVersionNoticeValue ? null : this.projectVersionNotice),
      projectPackagePendingExport:
          projectPackagePendingExport ??
          (forceProjectPackagePendingExportValue ? null : this.projectPackagePendingExport),
      projectPackageNotice:
          projectPackageNotice ??
          (forceProjectPackageNoticeValue ? null : this.projectPackageNotice),
      projectPackagePendingExportTarget:
          projectPackagePendingExportTarget ??
          (forceProjectPackagePendingExportTargetValue
              ? null
              : this.projectPackagePendingExportTarget),
    );
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptBreakdownState copyProjectVersionsState({
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
  OcptBreakdownState copyProjectPackageState({
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

  /// Copies this state with the catalogue [snapshot] read again, which moves the reload epoch.
  OcptBreakdownState copyWithReloadedSnapshot({required OcptBreakdownSnapshot? snapshot}) =>
      copyWith(snapshot: snapshot);

  /// Copies this state with the page [pageSetup] read again, which moves the reload epoch.
  OcptBreakdownState copyWithReloadedPageSetup({required OcptPageSetup pageSetup}) =>
      copyWith(pageSetup: pageSetup);

  /// Copies this state as loaded when no project is open: the dock preferences restored, no
  /// version previewed and the selection moved with the cause
  /// [OcptBreakdownSelectionCause.load].
  OcptBreakdownState copyToLoadedWithoutProject({
    required double leftDockFraction,
    required double rightDockFraction,
    required OcptBreakdownRightDockTab lastRightDockTab,
  }) => copyWith(
    isLoading: false,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    lastRightDockTab: lastRightDockTab,
    forcePreviewedVersionIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBreakdownSelectionCause.load,
  );

  /// Copies this state as loaded from the open project: the data read replaced, the scene and the
  /// target selections cleared and the selection moved with the cause
  /// [OcptBreakdownSelectionCause.load].
  ///
  /// No version is previewed when [previewedVersionId] is null.
  OcptBreakdownState copyToLoaded({
    required String title,
    required String? previewedVersionId,
    required String screenplayText,
    required OcptPageSetup pageSetup,
    required OcptBreakdownSnapshot snapshot,
    required double leftDockFraction,
    required double rightDockFraction,
    required OcptBreakdownRightDockTab lastRightDockTab,
  }) => copyWith(
    isLoading: false,
    title: title,
    previewedVersionId: previewedVersionId,
    forcePreviewedVersionIdValue: previewedVersionId == null,
    screenplayText: screenplayText,
    pageSetup: pageSetup,
    snapshot: snapshot,
    forceSelectedSceneIdValue: true,
    forceSelectedTargetRefValue: true,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    lastRightDockTab: lastRightDockTab,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBreakdownSelectionCause.load,
  );

  /// Copies this state with the scene [sceneId] selected.
  OcptBreakdownState copyWithSelectedScene({required String sceneId}) => copyWith(
    selectedSceneId: sceneId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBreakdownSelectionCause.scene,
  );

  /// Copies this state with the scene [sceneId] selected from its heading: the target selection
  /// cleared and the inspector shown, remembered as the last right dock tab.
  OcptBreakdownState copyWithSelectedSceneHeading({required String sceneId}) => copyWith(
    selectedSceneId: sceneId,
    forceSelectedTargetRefValue: true,
    rightDockTab: OcptBreakdownRightDockTab.inspector,
    lastRightDockTab: OcptBreakdownRightDockTab.inspector,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBreakdownSelectionCause.sceneHeading,
  );

  /// Copies this state with the target [targetId] of [targetKind] selected and the inspector shown,
  /// remembered as the last right dock tab.
  ///
  /// The scene [sceneId] is selected too when it [sceneExists], and the scene selection cleared
  /// otherwise.
  OcptBreakdownState copyWithSelectedTarget({
    required OcptBreakdownTargetKind targetKind,
    required String targetId,
    required String sceneId,
    required bool sceneExists,
  }) => copyWith(
    selectedTargetRef: (targetKind, targetId),
    selectedSceneId: sceneExists ? sceneId : null,
    forceSelectedSceneIdValue: !sceneExists,
    rightDockTab: OcptBreakdownRightDockTab.inspector,
    lastRightDockTab: OcptBreakdownRightDockTab.inspector,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBreakdownSelectionCause.target,
  );

  /// Copies this state with the scene [sceneId] selected when it [sceneExists], and the scene
  /// selection cleared otherwise, as the scene a target is anchored to.
  OcptBreakdownState copyWithAnchoredScene({required String sceneId, required bool sceneExists}) =>
      copyWith(
        selectedSceneId: sceneExists ? sceneId : null,
        forceSelectedSceneIdValue: !sceneExists,
        selectionEpoch: selectionEpoch + 1,
        selectionCause: OcptBreakdownSelectionCause.anchorScene,
      );

  /// Copies this state with the target selection cleared.
  OcptBreakdownState copyWithTargetSelectionCleared() => copyWith(
    forceSelectedTargetRefValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBreakdownSelectionCause.targetCleared,
  );

  /// Copies this state with the list panel hidden when it was shown, and shown when it was hidden.
  OcptBreakdownState copyWithToggledListPanel() =>
      copyWith(isListPanelVisible: !isListPanelVisible);

  /// Copies this state with the right dock tab [tab] shown and remembered, or the dock closed when
  /// [isAlreadyActive].
  OcptBreakdownState copyWithToggledRightDockTab({
    required OcptBreakdownRightDockTab tab,
    required bool isAlreadyActive,
  }) => copyWith(
    rightDockTab: isAlreadyActive ? null : tab,
    forceRightDockTabValue: isAlreadyActive,
    lastRightDockTab: tab,
  );

  /// Copies this state with the right dock closed.
  OcptBreakdownState copyWithRightDockClosed() => copyWith(forceRightDockTabValue: true);

  /// Copies this state with the right dock reopened on the last tab it showed.
  OcptBreakdownState copyWithRightDockReopened() => copyWith(rightDockTab: lastRightDockTab);

  /// Copies this state with the dock fractions [left] and [right], each one kept when null.
  OcptBreakdownState copyWithDockFractions({required double? left, required double? right}) =>
      copyWith(leftDockFraction: left, rightDockFraction: right);

  /// Copies this state with [hiddenLegendKeys] as the legend entries hidden.
  OcptBreakdownState copyWithHiddenLegendKeys({
    required Set<OcptBreakdownLegendKey> hiddenLegendKeys,
  }) => copyWith(hiddenLegendKeys: hiddenLegendKeys);

  /// Copies this state with every legend entry shown.
  OcptBreakdownState copyWithAllLegendKeysShown() => copyWith(hiddenLegendKeys: const {});

  /// Copies this state with [view] as the centre view, moving the selection with the cause
  /// [OcptBreakdownSelectionCause.centreView].
  OcptBreakdownState copyWithCentreView({required OcptBreakdownCentreView view}) => copyWith(
    centreView: view,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBreakdownSelectionCause.centreView,
  );

  /// Copies this state with the search query [query].
  ///
  /// The centre switches to the recap, moving the selection with the cause
  /// [OcptBreakdownSelectionCause.centreView], when [switchesToRecap].
  OcptBreakdownState copyWithSearchQuery({required String query, required bool switchesToRecap}) =>
      copyWith(
        searchQuery: query,
        centreView: switchesToRecap ? OcptBreakdownCentreView.recap : centreView,
        selectionEpoch: switchesToRecap ? selectionEpoch + 1 : null,
        selectionCause: switchesToRecap ? OcptBreakdownSelectionCause.centreView : null,
      );

  /// [selectedTarget]'s own suggested occurrences, computed from scratch by [copyWith] whenever one
  /// of the three things it derives from changes, and carried over unchanged otherwise.
  ///
  /// Empty while no target is selected — a passage is only ever suggested *for* something, and the
  /// section that shows these is the selected target's own.
  static List<OcptBreakdownSuggestion> _suggestionsOf({
    required OcptBreakdownSnapshot? snapshot,
    required String screenplayText,
    required (OcptBreakdownTargetKind, String)? selectedTargetRef,
  }) {
    if (snapshot == null || selectedTargetRef == null) {
      return const [];
    }

    return ocptBreakdownSuggestionsOf(
      scenes: snapshot.scenes,
      screenplayText: screenplayText,
      target: selectedTargetRef,
    );
  }

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
    leftDockFraction,
    rightDockFraction,
    reloadEpoch,
    selectionEpoch,
    selectionCause,
  ];
}
