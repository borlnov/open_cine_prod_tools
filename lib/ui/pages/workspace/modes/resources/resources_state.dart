// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:collection/collection.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// The state of `OcptResourcesBloc`.
///
/// Unlike the screenplay editor's own state, this one carries no single dirty/saving pair: a
/// person's discrete fields (colour, birth date, transport autonomy, image rights status/date)
/// and every sub-list (positions, skills, unavailabilities) write straight to the project database
/// the moment they change, and so do a role's cast member and kind, a location's colour, permit
/// status and date, a candidacy's status and audition date, and every scene ↔ set link. The six
/// `pending…FieldEdits` maps are the exception — the typed free-text fields of the person, role,
/// location, set, element and candidates card sheets all go through the same 2 s autosave
/// debounce, mirroring `OcptShotListState.pendingFieldEdits`.
class OcptResourcesState extends BlocStateForMixin<OcptResourcesState>
    with
        MixinOcptProjectVersionsState<OcptResourcesState>,
        MixinOcptProjectPackageState<OcptResourcesState>,
        MixinOcptModeState<OcptResourcesState> {
  /// Whether the resources catalogue is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The current project's currency, an ISO 4217 code: what the element sheet's cost field shows
  /// as its suffix, and what the exported workbook names its cost column after.
  final String currencyCode;

  /// The whole resources catalogue as last read from the project database, or null while nothing
  /// has been loaded yet.
  final OcptResourcesSnapshot? snapshot;

  /// The page setup the contact list export dialog is pre-filled with: the open project's own page
  /// format, paired with the app-wide margins preference, or the setup a previewed version was
  /// captured against — exactly as `OcptBreakdownState.pageSetup` is loaded.
  final OcptPageSetup pageSetup;

  /// The project's own mileage rates (`budget_mileage_rates`), in `sortKey` order — what the
  /// person sheet's logistics card offers its rate picker, read once on load like [currencyCode]
  /// rather than as part of [snapshot]: a rate is the project settings page's own catalogue, not a
  /// person's, and this mode only ever reads it.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The ids of every live Resources set of the project that holds a live floor plan row — the
  /// sets card's own `Floor plan · N sequences` / `No floor plan yet` line. Read once on load
  /// alongside [mileageRates], a light query
  /// (`OcptFloorPlanService.liveSetIdsWithPlan`) rather than a whole plan's worth of symbols.
  final Set<String> setIdsWithPlan;

  /// The left dock's currently active tab.
  ///
  /// Never persisted, unlike the shot list's visible columns or last right dock tab: it always
  /// starts on [OcptResourcesTab.people] on entry.
  final OcptResourcesTab activeTab;

  /// Whether the search field is shown, under `OcptResourcesTabBar` in the left dock.
  ///
  /// Never persisted, exactly like [activeTab]: search is a transient way of scanning whichever
  /// tab is open right now, not a project-wide or app-wide preference to restore on the next
  /// visit.
  final bool isSearchVisible;

  /// The text currently typed into the search field, filtering [activeTab]'s own list; empty while
  /// search is closed or nothing was typed.
  ///
  /// Never written anywhere — it only reads. Closing the search
  /// (`OcptResourcesBloc._onSearchToggled`) and changing tab (`_onTabSelected`) both clear it, so a
  /// hidden field, or one whose tab is no longer shown, can never keep filtering a list nobody can
  /// see any more.
  final String searchQuery;

  /// The id of the person currently selected, whose sheet the centre shows, or null while none is.
  final String? selectedPersonId;

  /// The id of the role currently selected, whose sheet the centre shows, or null while none is.
  final String? selectedRoleId;

  /// The id of the location currently selected, whose sheet the centre shows, or null while none
  /// is.
  final String? selectedLocationId;

  /// The id of the element currently selected, whose sheet the centre shows, or null while none is.
  final String? selectedElementId;

  /// Whether the left (list) dock is shown.
  final bool isListPanelVisible;

  /// The right dock's currently active tab, or null if the dock is closed.
  ///
  /// Unlike the shot list's own right dock, there is only one tab to reopen on
  /// ([OcptResourcesRightDockTab.versions]), so this mode keeps no "last tab" preference of its
  /// own.
  final OcptResourcesRightDockTab? rightDockTab;

  /// The left (list) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.resourcesLeftDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
  final double leftDockFraction;

  /// The right (versions) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.resourcesRightDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
  final double rightDockFraction;

  /// Whether the last write to the project database failed; shown as a transient SnackBar then
  /// dismissed.
  final bool hasWriteError;

  /// The cross-mode switch the sets card's own `Open in shot list` action just resolved
  /// (`OcptLocationsService.firstLinkedSceneOf`), or null while none is pending — a one-shot
  /// trigger the mode's own listener reads and reports taken into account
  /// (`OcptResourcesShotListRevealDismissedEvent`), exactly as `OcptShotListState
  /// .pendingCharacterNamePromptSymbolId` is consumed. `episodeId` is the screenplay
  /// `sceneId`/`setId`'s own first linked sequence belongs to, since a project holding several
  /// episodes must land the shot list mode on the right one.
  final ({String episodeId, String sceneId, String setId})? pendingShotListReveal;

  /// Every element field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// element id and the field, holding the raw text last typed for it.
  ///
  /// Rides the same debounce timer as the other typed fields the mode still holds (see
  /// `OcptResourcesBloc`'s own doc comment).
  final Map<(String, OcptElementField), String> pendingElementFieldEdits;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.reloadEpoch}
  @override
  final int reloadEpoch;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.selectionEpoch}
  @override
  final int selectionEpoch;

  /// What moved the selection the last time [selectionEpoch] advanced.
  final OcptResourcesSelectionCause selectionCause;

  /// How many times writing the typed edits failed (`OcptResourcesPendingEditsLostEvent`): a view
  /// bloc that sees it rise drops the edits it holds, since the mode has shown the write error and
  /// the fields fall back to what the database holds.
  final int lostEditsEpoch;

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

  /// Every person of [snapshot], in display order (empty while nothing is loaded).
  List<OcptPerson> get people => snapshot?.people ?? const [];

  /// The person [selectedPersonId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot], e.g. it was just deleted).
  OcptPerson? get selectedPerson {
    final selectedPersonId = this.selectedPersonId;
    if (selectedPersonId == null) {
      return null;
    }

    for (final person in people) {
      if (person.id == selectedPersonId) {
        return person;
      }
    }

    return null;
  }

  /// Every role of [snapshot], in display order (empty while nothing is loaded).
  List<OcptRole> get roles => snapshot?.roles ?? const [];

  /// The role [selectedRoleId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot], e.g. it was just deleted).
  OcptRole? get selectedRole {
    final selectedRoleId = this.selectedRoleId;
    if (selectedRoleId == null) {
      return null;
    }

    for (final role in roles) {
      if (role.id == selectedRoleId) {
        return role;
      }
    }

    return null;
  }

  /// The removed-role alert of [selectedRole], or null while none is selected or the selected role
  /// is still spoken in the screenplay.
  ///
  /// One alert at a time rather than every alert of the project: the banner reporting it lives
  /// inside the sheet of the role it names (see `OcptRoleSheet`), and the cast list of the left
  /// dock is what marks the other orphaned roles so they can be reached in turn.
  OcptRemovedRoleAlert? get selectedRoleAlert {
    final selectedRole = this.selectedRole;
    if (selectedRole == null) {
      return null;
    }

    return OcptRemovedRoleAlert.of(selectedRole);
  }

  /// Every orphaned-role alert found in the whole cast (ADR 0030, decision 4): what the mode-level
  /// compact banner is built from, above [selectedRoleAlert]'s own "one at a time" reasoning — the
  /// compact banner reports the whole cast, not just the selected role's sheet.
  List<OcptRemovedRoleAlert> get orphanedRoleAlerts => OcptRemovedRoleAlert.buildAll(roles);

  /// Every name-collision alert found in the whole cast (ADR 0030, decision 2), sorted stably.
  List<OcptRoleCollisionAlert> get roleCollisionAlerts => OcptRoleCollisionAlert.buildAll(roles);

  /// The collision alert naming [selectedRole] — either side of it — or null while none is
  /// selected or it collides with nothing. Mirrors [selectedRoleAlert]'s "one alert at a time"
  /// reasoning: the banner reporting it lives inside the sheet of one of the two roles it names.
  OcptRoleCollisionAlert? get selectedRoleCollisionAlert {
    final selectedRole = this.selectedRole;
    if (selectedRole == null) {
      return null;
    }

    return roleCollisionAlerts.firstWhereOrNull(
      (alert) =>
          alert.screenplayRoleId == selectedRole.id || alert.handAddedRoleId == selectedRole.id,
    );
  }

  /// The screenplay roles [alert]'s own orphaned role can be merged into: every live,
  /// `isFromScreenplay` role of [roles] that isn't itself orphaned and isn't [alert]'s own — the
  /// orphaned banner's `Merge with:` chips.
  List<OcptRole> mergeTargetsOf(OcptRemovedRoleAlert alert) => [
    for (final role in roles)
      if (role.isFromScreenplay && role.orphanedName == null && role.id != alert.roleId) role,
  ];

  /// Every live candidacy of role [roleId], in its own `sortKey` order — [snapshot]'s own group, or
  /// the empty list while nothing is loaded or [roleId] has none.
  List<OcptRoleCandidate> candidatesOfRole(String roleId) =>
      snapshot?.candidatesByRoleId[roleId] ?? const [];

  /// Every location of [snapshot], in display order (empty while nothing is loaded).
  List<OcptLocation> get locations => snapshot?.locations ?? const [];

  /// The location [selectedLocationId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot], e.g. it was just deleted).
  OcptLocation? get selectedLocation {
    final selectedLocationId = this.selectedLocationId;
    if (selectedLocationId == null) {
      return null;
    }

    for (final location in locations) {
      if (location.id == selectedLocationId) {
        return location;
      }
    }

    return null;
  }

  /// Every element of [snapshot], in display order (empty while nothing is loaded).
  List<OcptElement> get elements => snapshot?.elements ?? const [];

  /// The element [selectedElementId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot], e.g. it was just deleted).
  OcptElement? get selectedElement {
    final selectedElementId = this.selectedElementId;
    if (selectedElementId == null) {
      return null;
    }

    for (final element in elements) {
      if (element.id == selectedElementId) {
        return element;
      }
    }

    return null;
  }

  /// Every scene of the selected episode's screenplay, in source order (empty while nothing is
  /// loaded): what a set's scenes are picked from, and what an element's own scenes are picked
  /// from.
  List<OcptSceneRef> get scenes => snapshot?.scenes ?? const [];

  /// `snapshot.peopleCount`, the status bar's first counter.
  int get peopleCount => snapshot?.peopleCount ?? 0;

  /// `snapshot.roleCount`, the status bar's second counter.
  int get roleCount => snapshot?.roleCount ?? 0;

  /// `snapshot.positionCount`, the status bar's third counter.
  int get positionCount => snapshot?.positionCount ?? 0;

  /// `snapshot.locationCount`, the status bar's fourth counter.
  int get locationCount => snapshot?.locationCount ?? 0;

  /// `snapshot.elementCount`, the status bar's fifth counter.
  int get elementCount => snapshot?.elementCount ?? 0;

  /// Class constructor
  const OcptResourcesState({
    required this.isLoading,
    required this.title,
    required this.currencyCode,
    required this.snapshot,
    required this.pageSetup,
    required this.mileageRates,
    required this.setIdsWithPlan,
    required this.activeTab,
    required this.isSearchVisible,
    required this.searchQuery,
    required this.selectedPersonId,
    required this.selectedRoleId,
    required this.selectedLocationId,
    required this.selectedElementId,
    required this.isListPanelVisible,
    required this.rightDockTab,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.hasWriteError,
    required this.pendingShotListReveal,
    required this.pendingElementFieldEdits,
    required this.reloadEpoch,
    required this.selectionEpoch,
    required this.selectionCause,
    required this.lostEditsEpoch,
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
  OcptResourcesState.init()
    : isLoading = true,
      title = "",
      currencyCode = "",
      snapshot = null,
      pageSetup = const OcptPageSetup.standard(),
      mileageRates = const [],
      setIdsWithPlan = const {},
      activeTab = OcptResourcesTab.people,
      isSearchVisible = false,
      searchQuery = "",
      selectedPersonId = null,
      selectedRoleId = null,
      selectedLocationId = null,
      selectedElementId = null,
      isListPanelVisible = true,
      rightDockTab = null,
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      hasWriteError = false,
      pendingShotListReveal = null,
      pendingElementFieldEdits = const {},
      reloadEpoch = 0,
      selectionEpoch = 0,
      selectionCause = OcptResourcesSelectionCause.none,
      lostEditsEpoch = 0,
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
  /// **[reloadEpoch] moves by itself** whenever a copy replaces any of the data read from the
  /// project database ([snapshot], [currencyCode], [pageSetup], [mileageRates], [setIdsWithPlan]),
  /// so no handler can read the data again and forget to tell the views. An explicit [reloadEpoch]
  /// wins, for an emit that moves it without replacing anything.
  ///
  /// [snapshot] is only replaced when a new one is given: it never goes back to null once loaded,
  /// so it needs no force flag. [selectedPersonId], [selectedRoleId], [selectedLocationId],
  /// [selectedElementId] and [rightDockTab] all legitimately go back to null while the mode is
  /// alive (nothing selected any more, the dock closed), so each has its own force flag instead.
  @override
  OcptResourcesState copyWith({
    bool? isLoading,
    String? title,
    String? currencyCode,
    OcptResourcesSnapshot? snapshot,
    bool forceSnapshotValue = false,
    OcptPageSetup? pageSetup,
    List<OcptBudgetMileageRate>? mileageRates,
    Set<String>? setIdsWithPlan,
    OcptResourcesTab? activeTab,
    bool? isSearchVisible,
    String? searchQuery,
    String? selectedPersonId,
    bool forceSelectedPersonIdValue = false,
    String? selectedRoleId,
    bool forceSelectedRoleIdValue = false,
    String? selectedLocationId,
    bool forceSelectedLocationIdValue = false,
    String? selectedElementId,
    bool forceSelectedElementIdValue = false,
    bool? isListPanelVisible,
    OcptResourcesRightDockTab? rightDockTab,
    bool forceRightDockTabValue = false,
    double? leftDockFraction,
    double? rightDockFraction,
    bool? hasWriteError,
    ({String episodeId, String sceneId, String setId})? pendingShotListReveal,
    bool forcePendingShotListRevealValue = false,
    Map<(String, OcptElementField), String>? pendingElementFieldEdits,
    int? reloadEpoch,
    int? selectionEpoch,
    OcptResourcesSelectionCause? selectionCause,
    int? lostEditsEpoch,
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
  }) => OcptResourcesState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    currencyCode: currencyCode ?? this.currencyCode,
    snapshot: snapshot ?? (forceSnapshotValue ? null : this.snapshot),
    pageSetup: pageSetup ?? this.pageSetup,
    mileageRates: mileageRates ?? this.mileageRates,
    setIdsWithPlan: setIdsWithPlan ?? this.setIdsWithPlan,
    activeTab: activeTab ?? this.activeTab,
    isSearchVisible: isSearchVisible ?? this.isSearchVisible,
    searchQuery: searchQuery ?? this.searchQuery,
    selectedPersonId:
        selectedPersonId ?? (forceSelectedPersonIdValue ? null : this.selectedPersonId),
    selectedRoleId: selectedRoleId ?? (forceSelectedRoleIdValue ? null : this.selectedRoleId),
    selectedLocationId:
        selectedLocationId ?? (forceSelectedLocationIdValue ? null : this.selectedLocationId),
    selectedElementId:
        selectedElementId ?? (forceSelectedElementIdValue ? null : this.selectedElementId),
    isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
    rightDockTab: rightDockTab ?? (forceRightDockTabValue ? null : this.rightDockTab),
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    hasWriteError: hasWriteError ?? this.hasWriteError,
    pendingShotListReveal:
        pendingShotListReveal ??
        (forcePendingShotListRevealValue ? null : this.pendingShotListReveal),
    pendingElementFieldEdits: pendingElementFieldEdits ?? this.pendingElementFieldEdits,
    reloadEpoch:
        reloadEpoch ??
        (snapshot != null ||
                currencyCode != null ||
                pageSetup != null ||
                mileageRates != null ||
                setIdsWithPlan != null
            ? this.reloadEpoch + 1
            : this.reloadEpoch),
    selectionEpoch: selectionEpoch ?? this.selectionEpoch,
    selectionCause: selectionCause ?? this.selectionCause,
    lostEditsEpoch: lostEditsEpoch ?? this.lostEditsEpoch,
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

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptResourcesState copyProjectVersionsState({
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
  OcptResourcesState copyProjectPackageState({
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

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    currencyCode,
    snapshot,
    pageSetup,
    mileageRates,
    setIdsWithPlan,
    activeTab,
    isSearchVisible,
    searchQuery,
    selectedPersonId,
    selectedRoleId,
    selectedLocationId,
    selectedElementId,
    isListPanelVisible,
    rightDockTab,
    leftDockFraction,
    rightDockFraction,
    hasWriteError,
    pendingShotListReveal,
    pendingElementFieldEdits,
    reloadEpoch,
    selectionEpoch,
    selectionCause,
    lostEditsEpoch,
  ];
}
