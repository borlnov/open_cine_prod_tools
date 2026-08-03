// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// The state of `OcptResourcesBloc`.
///
/// Unlike the screenplay editor's own state, this one carries no single dirty/saving pair: a
/// person's discrete fields (colour, birth date, transport autonomy, image rights status/date)
/// and every sub-list (positions, skills, unavailabilities) write straight to the project database
/// the moment they change, and so do a role's cast member and kind, a location's colour, permit
/// status and date, and every scene ↔ set link. The four `pending…FieldEdits` maps are the
/// exception — the typed free-text fields of the person, role, location and set sheets all go
/// through the same 2 s autosave debounce, mirroring `OcptShotListState.pendingFieldEdits`.
class OcptResourcesState extends BlocStateForMixin<OcptResourcesState>
    with MixinOcptProjectVersionsState<OcptResourcesState> {
  /// Whether the resources catalogue is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole resources catalogue as last read from the project database, or null while nothing
  /// has been loaded yet.
  final OcptResourcesSnapshot? snapshot;

  /// The left dock's currently active tab.
  ///
  /// Never persisted, unlike the shot list's visible columns or last right dock tab: it always
  /// starts on [OcptResourcesTab.people] on entry.
  final OcptResourcesTab activeTab;

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

  /// Every field edit currently sitting in the field-edit autosave debounce, keyed by the person id
  /// and the field, holding the raw text last typed for it.
  ///
  /// What a field shows takes this map's entry over the person's own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write. An entry
  /// is removed the moment its write lands, whether through the debounce elapsing or an explicit
  /// flush.
  final Map<(String, OcptPersonField), String> pendingFieldEdits;

  /// Every role field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// role id and the field, holding the raw text last typed for it.
  ///
  /// Rides the same debounce timer as [pendingFieldEdits] (see `OcptResourcesBloc`'s own doc
  /// comment): a role's typed name or casting notes and a person's typed fields are flushed
  /// together, never one without the other.
  final Map<(String, OcptRoleField), String> pendingRoleFieldEdits;

  /// Every location field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// location id and the field, holding the raw text last typed for it.
  ///
  /// Rides the same debounce timer as [pendingFieldEdits] (see `OcptResourcesBloc`'s own doc
  /// comment).
  final Map<(String, OcptLocationField), String> pendingLocationFieldEdits;

  /// Every set field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// **set** id and the field, holding the raw text last typed for it.
  ///
  /// Keyed by the set rather than by the location holding it: a location sheet shows every one of
  /// its sets at once, each with its own code, name and notes, so two sets being typed into are two
  /// pending edits (see `OcptSetField`). Rides the same debounce timer as [pendingFieldEdits].
  final Map<(String, OcptSetField), String> pendingSetFieldEdits;

  /// Every element field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// element id and the field, holding the raw text last typed for it.
  ///
  /// Rides the same debounce timer as [pendingFieldEdits] (see `OcptResourcesBloc`'s own doc
  /// comment).
  final Map<(String, OcptElementField), String> pendingElementFieldEdits;

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

  /// Every scene of the project's primary screenplay, in source order (empty while nothing is
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
    required this.snapshot,
    required this.activeTab,
    required this.selectedPersonId,
    required this.selectedRoleId,
    required this.selectedLocationId,
    required this.selectedElementId,
    required this.isListPanelVisible,
    required this.rightDockTab,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.hasWriteError,
    required this.pendingFieldEdits,
    required this.pendingRoleFieldEdits,
    required this.pendingLocationFieldEdits,
    required this.pendingSetFieldEdits,
    required this.pendingElementFieldEdits,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
  });

  /// Init class constructor
  OcptResourcesState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      activeTab = OcptResourcesTab.people,
      selectedPersonId = null,
      selectedRoleId = null,
      selectedLocationId = null,
      selectedElementId = null,
      isListPanelVisible = true,
      rightDockTab = null,
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      hasWriteError = false,
      pendingFieldEdits = const {},
      pendingRoleFieldEdits = const {},
      pendingLocationFieldEdits = const {},
      pendingSetFieldEdits = const {},
      pendingElementFieldEdits = const {},
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot] is only replaced when a new one is given: it never goes back to null once loaded,
  /// so it needs no clear flag. [selectedPersonId], [selectedRoleId], [selectedLocationId],
  /// [selectedElementId] and [rightDockTab] all legitimately go back to null while the mode is alive
  /// (nothing selected any more, the dock closed), so each has its own clear flag instead.
  @override
  OcptResourcesState copyWith({
    bool? isLoading,
    String? title,
    OcptResourcesSnapshot? snapshot,
    OcptResourcesTab? activeTab,
    String? selectedPersonId,
    bool clearSelectedPersonId = false,
    String? selectedRoleId,
    bool clearSelectedRoleId = false,
    String? selectedLocationId,
    bool clearSelectedLocationId = false,
    String? selectedElementId,
    bool clearSelectedElementId = false,
    bool? isListPanelVisible,
    OcptResourcesRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    double? leftDockFraction,
    double? rightDockFraction,
    bool? hasWriteError,
    Map<(String, OcptPersonField), String>? pendingFieldEdits,
    Map<(String, OcptRoleField), String>? pendingRoleFieldEdits,
    Map<(String, OcptLocationField), String>? pendingLocationFieldEdits,
    Map<(String, OcptSetField), String>? pendingSetFieldEdits,
    Map<(String, OcptElementField), String>? pendingElementFieldEdits,
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
  }) => OcptResourcesState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? this.snapshot,
    activeTab: activeTab ?? this.activeTab,
    selectedPersonId: clearSelectedPersonId ? null : (selectedPersonId ?? this.selectedPersonId),
    selectedRoleId: clearSelectedRoleId ? null : (selectedRoleId ?? this.selectedRoleId),
    selectedLocationId: clearSelectedLocationId
        ? null
        : (selectedLocationId ?? this.selectedLocationId),
    selectedElementId: clearSelectedElementId
        ? null
        : (selectedElementId ?? this.selectedElementId),
    isListPanelVisible: isListPanelVisible ?? this.isListPanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    hasWriteError: hasWriteError ?? this.hasWriteError,
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    pendingRoleFieldEdits: pendingRoleFieldEdits ?? this.pendingRoleFieldEdits,
    pendingLocationFieldEdits: pendingLocationFieldEdits ?? this.pendingLocationFieldEdits,
    pendingSetFieldEdits: pendingSetFieldEdits ?? this.pendingSetFieldEdits,
    pendingElementFieldEdits: pendingElementFieldEdits ?? this.pendingElementFieldEdits,
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
  OcptResourcesState copyProjectVersionsState({
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
    snapshot,
    activeTab,
    selectedPersonId,
    selectedRoleId,
    selectedLocationId,
    selectedElementId,
    isListPanelVisible,
    rightDockTab,
    leftDockFraction,
    rightDockFraction,
    hasWriteError,
    pendingFieldEdits,
    pendingRoleFieldEdits,
    pendingLocationFieldEdits,
    pendingSetFieldEdits,
    pendingElementFieldEdits,
  ];
}
