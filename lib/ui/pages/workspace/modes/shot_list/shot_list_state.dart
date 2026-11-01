// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state_derived.dart';

/// The state of `OcptShotListBloc`.
///
/// Unlike the screenplay editor's own state, this one carries no single dirty/saving pair: most
/// of a shot's fields (status, a difficulty axis, a character chip) write straight to the project
/// database the moment they change. The typed free-text fields are the exception, and each view bloc
/// holds its own in a 2 s autosave debounce.
class OcptShotListState extends BlocStateForMixin<OcptShotListState>
    with
        MixinOcptProjectVersionsState<OcptShotListState>,
        MixinOcptProjectPackageState<OcptShotListState>,
        MixinOcptModeState<OcptShotListState> {
  /// Whether the shot list is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole shot list as last read from the project database, or null while nothing has been
  /// loaded yet.
  final OcptShotListSnapshot? snapshot;

  /// The page setup the screenplay is typeset with, as last loaded by the bloc.
  ///
  /// The shot list itself never prints anything; this is what the scenario coverage dialog's
  /// simulated paper sheet is laid out with, so the sequence it shows reads exactly like the same
  /// text does in the screenplay mode's own preview (`OcptPageSetup.toMetrics` being the single
  /// entry point both go through).
  final OcptPageSetup pageSetup;

  /// The screenplay's Fountain text, as last loaded by the bloc.
  ///
  /// Every scene's own text is sliced out of this string using
  /// `OcptSceneShotSequence.charStart`/`charEnd`: `buildSelectedCoverageLayout` is what does that
  /// slicing for the selected sequence, and `OcptShotCoverageService.markAsChecked` needs the
  /// whole string rather than a single scene's slice (see `OcptShotListBloc`'s own doc comment on
  /// its `Mark as checked` handler).
  final String screenplayText;

  /// The [OcptShotSequence.id] of the sequence currently selected, or null while none is (an
  /// empty screenplay has no sequence to select in the first place).
  final String? selectedSequenceId;

  /// The id of the shot currently selected, or null while none is.
  ///
  /// Always a shot of `selectedSequence` while both are set: selecting a shot selects its
  /// sequence too, and selecting another sequence clears the shot.
  final String? selectedShotId;

  /// Which of the mode's centre views is currently shown, persisted through
  /// `OcptPropertiesManager.shotListLastCentreView`. The switch offering it is
  /// `OcptShotListCentreHeader`; a compact width shows the table regardless of this value (see
  /// `OcptShotListState.isBoardShown` on the mode side — the mode itself decides that, this state
  /// only ever carries what the user last picked).
  final OcptShotListCentreView centreView;

  /// The whole storyboard of the selected episode's screenplay, as last read by
  /// `OcptStoryboardService.loadStoryboard`, or null while nothing has been loaded yet. Reloaded
  /// after every write a board affordance makes (importing, replacing, reordering or deleting a
  /// panel, flushing a pending comment edit).
  final OcptStoryboardSnapshot? storyboardSnapshot;

  /// The whole floor plans of the selected episode's screenplay, as last read by
  /// `OcptFloorPlanService.loadFloorPlans`, or null while nothing has been loaded yet. Reloaded
  /// after every write a floor plans affordance makes (a set's own CRUD, placing/moving/resizing a
  /// symbol, the underlay's own CRUD).
  final OcptFloorPlanSnapshot? floorPlanSnapshot;

  /// The id of the set currently shown on the floor plans view, or null while none is (no set
  /// exists yet for the selected sequence, or the selected sequence is the orphan group, which has
  /// no scene to hold one).
  ///
  /// Cleared whenever [selectedSequenceId] changes: a set only ever belongs to the sequence
  /// currently shown.
  final String? selectedSetId;

  /// The project's whole Resources catalogue — every location and its own live sets, each
  /// carrying the scenes it is linked to — as last read by `OcptLocationsService.loadLocations`:
  /// the empty-state gallery's own catalogue, the `＋ Set`
  /// menu's own `Link an existing set ▸`/`Create a set ▸` groups, and what
  /// `ocptSceneSetSuggestionOf` reads to suggest one for the selected sequence's own heading.
  /// Project-wide, unlike [floorPlanSnapshot]'s own per-screenplay read.
  final List<OcptLocation> locations;

  /// The set-scope symbols of every live Resources set of the project, keyed by set id, as last
  /// read by `OcptFloorPlanService.loadSetScopeSymbolsByProjectSetId` — the empty-state gallery's
  /// own thumbnail content: a thumbnail draws a set's own
  /// décor alone, never what a sequence or a shot placed on it.
  final Map<String, List<OcptFloorPlanSymbol>> setScopeSymbolsBySetId;

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

  /// The screenplay's whole cast — the speaking roles and the characters introduced in capitals in
  /// an action line alike, see `fountain_kit`'s `screenplayCharactersOf` — normalised through
  /// `normalizeCharacterName` and in first-appearance order, as parsed once on entry.
  ///
  /// Kept for `OcptShotListBloc`'s own internal use resolving a scenario coverage range's covered
  /// text onto [roles] (`_attachCharactersCoveredBy`) rather than for display any more: the
  /// inspector's character chips are built from [roles], the production's whole cast, not from this
  /// screenplay-only list (`OcptShotCharacterChips`).
  final List<String> screenplayCharacters;

  /// The production's whole cast — every live role, in `sortKey` order — as last read by
  /// `OcptRoleIndexService.loadRoles`: what the inspector's character chips are built from
  /// (`OcptShotCharacterChips`), and what `orphanedRoleAlerts` and `roleCollisionAlerts` are
  /// derived from.
  final List<OcptRole> roles;

  /// The selected episode's own suggestion lists the inspector's free-text fields with suggestions
  /// read from, reloaded after every field-edit flush.
  final OcptShotFieldSuggestions suggestions;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.reloadEpoch}
  @override
  final int reloadEpoch;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.selectionEpoch}
  @override
  final int selectionEpoch;

  /// What moved the selection the last time [selectionEpoch] advanced: the views clear different
  /// things for different gestures (see [OcptShotListSelectionCause]).
  final OcptShotListSelectionCause selectionCause;

  /// The id of the row [selectionCause] is about, for the causes that name one (the symbol that was
  /// removed or hidden, the arrow that was removed), and whatever it last was otherwise: a view
  /// reads it only for those causes.
  final String? selectionTargetId;

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

  /// Class constructor
  const OcptShotListState({
    required this.isLoading,
    required this.title,
    required this.snapshot,
    required this.pageSetup,
    required this.screenplayText,
    required this.selectedSequenceId,
    required this.selectedShotId,
    required this.centreView,
    required this.storyboardSnapshot,
    required this.floorPlanSnapshot,
    required this.selectedSetId,
    required this.locations,
    required this.setScopeSymbolsBySetId,
    required this.isSequencePanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.visibleColumns,
    required this.hasWriteError,
    required this.screenplayCharacters,
    required this.roles,
    required this.suggestions,
    required this.reloadEpoch,
    required this.selectionEpoch,
    required this.selectionCause,
    required this.selectionTargetId,
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
  OcptShotListState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      pageSetup = const OcptPageSetup.standard(),
      screenplayText = "",
      selectedSequenceId = null,
      selectedShotId = null,
      centreView = OcptShotListCentreView.table,
      storyboardSnapshot = null,
      floorPlanSnapshot = null,
      selectedSetId = null,
      locations = const [],
      setScopeSymbolsBySetId = const {},
      isSequencePanelVisible = true,
      rightDockTab = null,
      lastRightDockTab = OcptShotListRightDockTab.inspector,
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      visibleColumns = OcptShotListColumn.defaultVisibleColumns,
      hasWriteError = false,
      screenplayCharacters = const [],
      roles = const [],
      suggestions = const OcptShotFieldSuggestions.empty(),
      reloadEpoch = 0,
      selectionEpoch = 0,
      selectionCause = OcptShotListSelectionCause.none,
      selectionTargetId = null,
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
  /// [snapshot] is only replaced when a new one is given: it never goes back to null once loaded,
  /// so it needs no force flag. [selectedSequenceId], [selectedShotId], [rightDockTab] all legitimately go back to null while the mode is alive (nothing selected any
  /// more, the dock closed), so each has its own force flag instead.
  ///
  /// **[reloadEpoch] moves by itself** whenever a copy replaces any of the data read from the
  /// project database ([snapshot], [storyboardSnapshot], [floorPlanSnapshot], [locations],
  /// [setScopeSymbolsBySetId], [suggestions], [roles], [pageSetup]), so no handler can read the
  /// data again and forget to tell the views. An explicit [reloadEpoch] wins, for an emit that
  /// moves it without replacing anything.
  @override
  OcptShotListState copyWith({
    bool? isLoading,
    String? title,
    OcptShotListSnapshot? snapshot,
    bool forceSnapshotValue = false,
    OcptPageSetup? pageSetup,
    String? screenplayText,
    String? selectedSequenceId,
    bool forceSelectedSequenceIdValue = false,
    String? selectedShotId,
    bool forceSelectedShotIdValue = false,
    OcptShotListCentreView? centreView,
    OcptStoryboardSnapshot? storyboardSnapshot,
    bool forceStoryboardSnapshotValue = false,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    bool forceFloorPlanSnapshotValue = false,
    String? selectedSetId,
    bool forceSelectedSetIdValue = false,
    List<OcptLocation>? locations,
    Map<String, List<OcptFloorPlanSymbol>>? setScopeSymbolsBySetId,
    bool? isSequencePanelVisible,
    OcptShotListRightDockTab? rightDockTab,
    bool forceRightDockTabValue = false,
    OcptShotListRightDockTab? lastRightDockTab,
    double? leftDockFraction,
    double? rightDockFraction,
    Set<OcptShotListColumn>? visibleColumns,
    bool? hasWriteError,
    List<String>? screenplayCharacters,
    List<OcptRole>? roles,
    OcptShotFieldSuggestions? suggestions,
    int? reloadEpoch,
    int? selectionEpoch,
    OcptShotListSelectionCause? selectionCause,
    String? selectionTargetId,
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
  }) => OcptShotListState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? (forceSnapshotValue ? null : this.snapshot),
    pageSetup: pageSetup ?? this.pageSetup,
    screenplayText: screenplayText ?? this.screenplayText,
    selectedSequenceId:
        selectedSequenceId ?? (forceSelectedSequenceIdValue ? null : this.selectedSequenceId),
    selectedShotId: selectedShotId ?? (forceSelectedShotIdValue ? null : this.selectedShotId),
    centreView: centreView ?? this.centreView,
    storyboardSnapshot:
        storyboardSnapshot ?? (forceStoryboardSnapshotValue ? null : this.storyboardSnapshot),
    floorPlanSnapshot:
        floorPlanSnapshot ?? (forceFloorPlanSnapshotValue ? null : this.floorPlanSnapshot),
    selectedSetId: selectedSetId ?? (forceSelectedSetIdValue ? null : this.selectedSetId),
    locations: locations ?? this.locations,
    setScopeSymbolsBySetId: setScopeSymbolsBySetId ?? this.setScopeSymbolsBySetId,
    isSequencePanelVisible: isSequencePanelVisible ?? this.isSequencePanelVisible,
    rightDockTab: rightDockTab ?? (forceRightDockTabValue ? null : this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    visibleColumns: visibleColumns ?? this.visibleColumns,
    hasWriteError: hasWriteError ?? this.hasWriteError,
    screenplayCharacters: screenplayCharacters ?? this.screenplayCharacters,
    roles: roles ?? this.roles,
    suggestions: suggestions ?? this.suggestions,
    reloadEpoch:
        reloadEpoch ??
        (_isDataReplacedBy(
              snapshot: snapshot,
              storyboardSnapshot: storyboardSnapshot,
              floorPlanSnapshot: floorPlanSnapshot,
              locations: locations,
              setScopeSymbolsBySetId: setScopeSymbolsBySetId,
              suggestions: suggestions,
              roles: roles,
              pageSetup: pageSetup,
            )
            ? this.reloadEpoch + 1
            : this.reloadEpoch),
    selectionEpoch: selectionEpoch ?? this.selectionEpoch,
    selectionCause: selectionCause ?? this.selectionCause,
    selectionTargetId: selectionTargetId ?? this.selectionTargetId,
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
  );

  /// Whether any of the given pieces of data read from the project database is a new value, i.e.
  /// whether a copy made with them re-reads the data (see [copyWith]).
  static bool _isDataReplacedBy({
    required Object? snapshot,
    required Object? storyboardSnapshot,
    required Object? floorPlanSnapshot,
    required Object? locations,
    required Object? setScopeSymbolsBySetId,
    required Object? suggestions,
    required Object? roles,
    required Object? pageSetup,
  }) =>
      snapshot != null ||
      storyboardSnapshot != null ||
      floorPlanSnapshot != null ||
      locations != null ||
      setScopeSymbolsBySetId != null ||
      suggestions != null ||
      roles != null ||
      pageSetup != null;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptShotListState copyProjectVersionsState({
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
  OcptShotListState copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
  }) => copyWith(
    projectPackagePendingExport: projectPackagePendingExport,
    forceProjectPackagePendingExportValue: forceProjectPackagePendingExportValue,
    projectPackageNotice: projectPackageNotice,
    forceProjectPackageNoticeValue: forceProjectPackageNoticeValue,
  );

  /// Copies this state with the data a reload read, each given part replacing its counterpart.
  ///
  /// A null part is kept as it is. [reloadEpoch] moves by one, whichever parts were given.
  OcptShotListState copyWithReloadedData({
    required OcptShotListSnapshot? snapshot,
    required OcptShotFieldSuggestions? suggestions,
    required OcptStoryboardSnapshot? storyboardSnapshot,
    required OcptFloorPlanSnapshot? floorPlanSnapshot,
    required List<OcptLocation>? locations,
    required Map<String, List<OcptFloorPlanSymbol>>? setScopeSymbolsBySetId,
    required List<OcptRole>? roles,
  }) => copyWith(
    snapshot: snapshot,
    suggestions: suggestions,
    storyboardSnapshot: storyboardSnapshot,
    floorPlanSnapshot: floorPlanSnapshot,
    locations: locations,
    setScopeSymbolsBySetId: setScopeSymbolsBySetId,
    roles: roles,
    reloadEpoch: reloadEpoch + 1,
  );

  /// Copies this state as loaded when no project is open: the preferences restored, no snapshot,
  /// and no version previewed.
  OcptShotListState copyToLoadedWithoutProject({
    required double leftDockFraction,
    required double rightDockFraction,
    required Set<OcptShotListColumn> visibleColumns,
    required OcptShotListRightDockTab lastRightDockTab,
    required OcptShotListCentreView centreView,
  }) => copyWith(
    isLoading: false,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    visibleColumns: visibleColumns,
    lastRightDockTab: lastRightDockTab,
    centreView: centreView,
    forcePreviewedVersionIdValue: true,
  );

  /// Copies this state as loaded from the open project: everything read from it, the preferences
  /// restored and the first selection made, whose cause is [OcptShotListSelectionCause.load].
  ///
  /// Each selection goes back to null when its argument is, and so does the previewed version id
  /// when [previewedVersion] is.
  OcptShotListState copyToLoaded({
    required String title,
    required OcptProjectVersion? previewedVersion,
    required OcptShotListSnapshot snapshot,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required List<OcptLocation> locations,
    required Map<String, List<OcptFloorPlanSymbol>> setScopeSymbolsBySetId,
    required OcptPageSetup pageSetup,
    required String screenplayText,
    required List<OcptRole> roles,
    required String? selectedSequenceId,
    required String? selectedShotId,
    required String? selectedSetId,
    required double leftDockFraction,
    required double rightDockFraction,
    required Set<OcptShotListColumn> visibleColumns,
    required OcptShotListRightDockTab lastRightDockTab,
    required OcptShotListCentreView centreView,
    required List<String> screenplayCharacters,
    required OcptShotFieldSuggestions suggestions,
  }) => copyWith(
    isLoading: false,
    title: title,
    previewedVersionId: previewedVersion?.id,
    forcePreviewedVersionIdValue: previewedVersion == null,
    snapshot: snapshot,
    storyboardSnapshot: storyboardSnapshot,
    floorPlanSnapshot: floorPlanSnapshot,
    locations: locations,
    setScopeSymbolsBySetId: setScopeSymbolsBySetId,
    pageSetup: pageSetup,
    screenplayText: screenplayText,
    roles: roles,
    selectedSequenceId: selectedSequenceId,
    forceSelectedSequenceIdValue: snapshot.sequences.isEmpty,
    selectedShotId: selectedShotId,
    forceSelectedShotIdValue: selectedShotId == null,
    selectedSetId: selectedSetId,
    forceSelectedSetIdValue: selectedSetId == null,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    visibleColumns: visibleColumns,
    lastRightDockTab: lastRightDockTab,
    centreView: centreView,
    screenplayCharacters: screenplayCharacters,
    suggestions: suggestions,
    reloadEpoch: reloadEpoch + 1,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptShotListSelectionCause.load,
  );

  /// Copies this state with sequence [sequenceId] selected, [selectedShotId] and [selectedSetId]
  /// as its selected shot and set (each going back to null when null).
  ///
  /// The selection's cause says whether [isSameSequence] was picked again.
  OcptShotListState copyWithSelectedSequence({
    required String sequenceId,
    required String? selectedShotId,
    required String? selectedSetId,
    required bool isSameSequence,
  }) => copyWith(
    selectedSequenceId: sequenceId,
    selectedShotId: selectedShotId,
    forceSelectedShotIdValue: selectedShotId == null,
    selectedSetId: selectedSetId,
    forceSelectedSetIdValue: selectedSetId == null,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: isSameSequence
        ? OcptShotListSelectionCause.sequenceReselected
        : OcptShotListSelectionCause.sequence,
  );

  /// Copies this state with shot [shotId] of sequence [sequenceId] selected, the inspector tab
  /// showing.
  OcptShotListState copyWithSelectedShot({required String sequenceId, required String shotId}) =>
      copyWith(
        selectedSequenceId: sequenceId,
        selectedShotId: shotId,
        rightDockTab: OcptShotListRightDockTab.inspector,
        lastRightDockTab: OcptShotListRightDockTab.inspector,
        selectionEpoch: selectionEpoch + 1,
        selectionCause: OcptShotListSelectionCause.shot,
      );

  /// Copies this state with [snapshot] as the shot list that holds the freshly created [shotId] of
  /// sequence [sequenceId], selected with the inspector tab showing.
  ///
  /// A null [shotId] keeps the current shot selection.
  OcptShotListState copyWithCreatedShot({
    required OcptShotListSnapshot snapshot,
    required String sequenceId,
    required String? shotId,
  }) => copyWith(
    snapshot: snapshot,
    selectedSequenceId: sequenceId,
    selectedShotId: shotId,
    rightDockTab: OcptShotListRightDockTab.inspector,
    lastRightDockTab: OcptShotListRightDockTab.inspector,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptShotListSelectionCause.shotCreated,
  );

  /// Copies this state with the sequences dock's visibility flipped.
  OcptShotListState copyWithSequencePanelToggled() =>
      copyWith(isSequencePanelVisible: !isSequencePanelVisible);

  /// Copies this state with [tab] as the last right dock tab, and the dock closed when
  /// [isAlreadyActive] or showing [tab] otherwise.
  OcptShotListState copyWithRightDockTabSelected({
    required OcptShotListRightDockTab tab,
    required bool isAlreadyActive,
  }) => copyWith(
    rightDockTab: isAlreadyActive ? null : tab,
    forceRightDockTabValue: isAlreadyActive,
    lastRightDockTab: tab,
  );

  /// Copies this state with the right dock closed.
  OcptShotListState copyWithRightDockClosed() => copyWith(forceRightDockTabValue: true);

  /// Copies this state with the right dock opened on the last tab it showed.
  OcptShotListState copyWithRightDockReopened() => copyWith(rightDockTab: lastRightDockTab);

  /// Copies this state with [left] and [right] as the dock fractions.
  ///
  /// A null fraction keeps the current one.
  OcptShotListState copyWithDockFractions({required double? left, required double? right}) =>
      copyWith(leftDockFraction: left, rightDockFraction: right);

  /// Copies this state with [visibleColumns] as the optional table columns shown.
  OcptShotListState copyWithVisibleColumns({required Set<OcptShotListColumn> visibleColumns}) =>
      copyWith(visibleColumns: visibleColumns);

  /// Copies this state with [pageSetup] as the screenplay's page setup.
  OcptShotListState copyWithPageSetup({required OcptPageSetup pageSetup}) =>
      copyWith(pageSetup: pageSetup);

  /// Copies this state after a shot was deleted, with the data read back and [reselectedShotId] as
  /// the selected shot (going back to null when null).
  ///
  /// The selection moves, with the cause [OcptShotListSelectionCause.shotDeleted], only when
  /// [wasSelected].
  OcptShotListState copyWithDeletedShot({
    required OcptShotListSnapshot snapshot,
    required OcptShotFieldSuggestions suggestions,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required String? reselectedShotId,
    required bool wasSelected,
  }) => copyWith(
    snapshot: snapshot,
    suggestions: suggestions,
    storyboardSnapshot: storyboardSnapshot,
    floorPlanSnapshot: floorPlanSnapshot,
    selectedShotId: reselectedShotId,
    forceSelectedShotIdValue: reselectedShotId == null,
    reloadEpoch: reloadEpoch + 1,
    selectionEpoch: wasSelected ? selectionEpoch + 1 : null,
    selectionCause: wasSelected ? OcptShotListSelectionCause.shotDeleted : null,
  );

  /// Copies this state with [view] as the centre view.
  OcptShotListState copyWithCentreView({required OcptShotListCentreView view}) =>
      copyWith(centreView: view);

  /// Copies this state with set [setId] selected.
  OcptShotListState copyWithSelectedSet({required String setId}) => copyWith(
    selectedSetId: setId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptShotListSelectionCause.set,
  );

  /// Copies this state with set [setId], just added to the selected sequence, selected.
  OcptShotListState copyWithAddedSet({required String setId}) => copyWith(
    selectedSetId: setId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptShotListSelectionCause.setAdded,
  );

  /// Copies this state with [setId] selected after the selected set was removed, going back to
  /// null when null.
  OcptShotListState copyWithRemovedSetFallback({required String? setId}) => copyWith(
    selectedSetId: setId,
    forceSelectedSetIdValue: setId == null,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptShotListSelectionCause.setRemoved,
  );

  /// Copies this state with the selection moved for [cause], naming the row [targetId].
  ///
  /// A null [targetId] keeps the current one.
  OcptShotListState copyWithMovedSelection({
    required OcptShotListSelectionCause cause,
    required String? targetId,
  }) => copyWith(
    selectionEpoch: selectionEpoch + 1,
    selectionCause: cause,
    selectionTargetId: targetId,
  );

  /// Copies this state with the write error raised.
  OcptShotListState copyToWriteFailed() => copyWith(hasWriteError: true);

  /// Copies this state with the write error dismissed.
  OcptShotListState copyWithWriteErrorDismissed() => copyWith(hasWriteError: false);

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    snapshot,
    pageSetup,
    screenplayText,
    selectedSequenceId,
    selectedShotId,
    centreView,
    storyboardSnapshot,
    floorPlanSnapshot,
    selectedSetId,
    locations,
    setScopeSymbolsBySetId,
    isSequencePanelVisible,
    rightDockTab,
    lastRightDockTab,
    leftDockFraction,
    rightDockFraction,
    visibleColumns,
    hasWriteError,
    screenplayCharacters,
    roles,
    suggestions,
    reloadEpoch,
    selectionEpoch,
    selectionCause,
    selectionTargetId,
  ];
}
