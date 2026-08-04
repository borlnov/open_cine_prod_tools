// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_delete_confirm_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_set_suggestion.dart';

/// The resources production mode: the four-tab list (people, roles, locations, elements) on the
/// left, the selected item's editable sheet in the centre, and the shared `Versions` dock tab on
/// the right.
///
/// All four tabs answer the same gesture: a record is picked on the left and edited in the centre,
/// through `OcptPersonSheet`, `OcptRoleSheet`, `OcptLocationSheet` and `OcptElementSheet`
/// respectively — the address book, the cast, the locations with their sets, and the catalogue of
/// everything that must be on set and is not a person.
/// While a project version is being previewed, the mode shows that version's catalogue instead of
/// the working copy's, and shows it read-only: everything that would write — the `+ Add …`
/// buttons and every field, picker and delete action of the three sheets — is withheld, and the
/// shell carries the band naming the version.
class OcptResourcesMode extends StatelessWidget {
  /// Creates the resources mode.
  const OcptResourcesMode({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptResourcesBloc(), child: const _ResourcesView());
}

/// The content of [OcptResourcesMode], separated from it so [OcptResourcesMode] only wires the
/// [OcptResourcesBloc] up (RFL3).
///
/// This is a StatefulWidget (the documented RFL1 exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame.
class _ResourcesView extends StatefulWidget {
  /// Class constructor
  const _ResourcesView();

  @override
  State<_ResourcesView> createState() => _ResourcesViewState();
}

/// The state of [_ResourcesView]: owns the dock layout controller and keeps it in sync with the
/// fractions the bloc persisted.
class _ResourcesViewState extends State<_ResourcesView> {
  /// The live source of truth for the two dock fractions while dragging a divider. Initialized
  /// with the defaults; synced to the bloc's persisted values once the load (or a reset)
  /// resolves, in [_onStateChanged].
  final OcptWorkspaceDockLayoutController _dockLayoutController = OcptWorkspaceDockLayoutController(
    leftFraction: OcptWorkspaceDock.leftDefaultFraction,
    rightFraction: OcptWorkspaceDock.rightDefaultFraction,
  );

  @override
  void deactivate() {
    // `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
    // this whole subtree out, and so does the workspace's own back navigation), so flushing here
    // — rather than in `dispose()`, or waiting out the field-edit debounce — is what guarantees
    // the last couple of seconds of typing in the person sheet survive it. See
    // `OcptShotListMode`'s own `deactivate()` for the same reasoning.
    unawaited(context.read<OcptResourcesBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptResourcesBloc, OcptResourcesState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        isReadOnly: state.isPreviewingVersion,
        onBack: () => context.read<OcptResourcesBloc>().add(const OcptResourcesBackRequestedEvent()),
        modeLabel: Tr.of(context).workspaceModeLabelResources,
        overflowEntries: _buildOverflowEntries(context, state),
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () => context.read<OcptResourcesBloc>().add(
          const OcptResourcesLeftPanelToggledEvent(),
        ),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () => context.read<OcptResourcesBloc>().add(
          const OcptResourcesRightDockToggledEvent(),
        ),
        banner: _buildReadOnlyBanner(context, state),
        leftPanel: _buildListPanel(context, state),
        rightPanel: _buildRightDock(context, state),
        centre: _buildCentre(context, state),
        statusBar: OcptResourcesStatusBar(
          peopleCount: state.peopleCount,
          roleCount: state.roleCount,
          positionCount: state.positionCount,
          locationCount: state.locationCount,
          elementCount: state.elementCount,
        ),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) => context.read<OcptResourcesBloc>().add(
          OcptResourcesDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
        ),
      );
    },
  );

  /// Builds the mode's `⋮` overflow menu entries: the XLSX export first, then resetting the panel
  /// layout, mirroring `OcptShotListMode._buildOverflowEntries`.
  ///
  /// The export entry is disabled while the whole catalogue is empty: there would be nothing in
  /// any of the four sheets but their header row.
  List<PopupMenuEntry<void>> _buildOverflowEntries(
    BuildContext context,
    OcptResourcesState state,
  ) => [
    PopupMenuItem<void>(
      enabled: state.peopleCount + state.roleCount + state.locationCount + state.elementCount > 0,
      onTap: () => _requestXlsxExport(context, state),
      child: Text(Tr.of(context).resourcesExportXlsxMenuAction),
    ),
    PopupMenuItem<void>(
      onTap: () =>
          context.read<OcptResourcesBloc>().add(const OcptResourcesDockLayoutResetEvent()),
      child: Text(Tr.of(context).resourcesResetPanelLayoutAction),
    ),
  ];

  /// Dispatches the XLSX export request, resolving here — the last place with a [BuildContext] —
  /// every localized string the four sheets and the native save dialog carry.
  void _requestXlsxExport(BuildContext context, OcptResourcesState state) {
    final tr = Tr.of(context);

    context.read<OcptResourcesBloc>().add(
      OcptResourcesXlsxExportRequestedEvent(
        labels: ocptResourcesXlsxLabelsOf(context, state.scenes),
        fileTypeLabel: tr.resourcesExportXlsxFileTypeLabel,
      ),
    );
  }

  /// Builds the left dock, the shell's `leftPanel`, or null while it's hidden.
  ///
  /// Every `+ Add …` action is withheld — a null callback — while a project version is being
  /// previewed: the list is then a way of reading that version, not of changing it.
  Widget? _buildListPanel(BuildContext context, OcptResourcesState state) {
    if (!state.isListPanelVisible) {
      return null;
    }

    return OcptResourcesListPanel(
      activeTab: state.activeTab,
      people: state.people,
      selectedPersonId: state.selectedPersonId,
      roles: state.roles,
      selectedRoleId: state.selectedRoleId,
      locations: state.locations,
      selectedLocationId: state.selectedLocationId,
      elements: state.elements,
      selectedElementId: state.selectedElementId,
      onTabSelected: (tab) =>
          context.read<OcptResourcesBloc>().add(OcptResourcesTabSelectedEvent(tab: tab)),
      onPersonSelected: (personId) => context.read<OcptResourcesBloc>().add(
        OcptResourcesPersonSelectedEvent(personId: personId),
      ),
      onRoleSelected: (roleId) =>
          context.read<OcptResourcesBloc>().add(OcptResourcesRoleSelectedEvent(roleId: roleId)),
      onLocationSelected: (locationId) => context.read<OcptResourcesBloc>().add(
        OcptResourcesLocationSelectedEvent(locationId: locationId),
      ),
      onElementSelected: (elementId) => context.read<OcptResourcesBloc>().add(
        OcptResourcesElementSelectedEvent(elementId: elementId),
      ),
      onAddPersonRequested: state.isPreviewingVersion
          ? null
          : () => context.read<OcptResourcesBloc>().add(
              const OcptResourcesPersonCreationRequestedEvent(),
            ),
      onAddRoleRequested: state.isPreviewingVersion
          ? null
          : (kind) => context.read<OcptResourcesBloc>().add(
              OcptResourcesRoleCreationRequestedEvent(kind: kind),
            ),
      onAddLocationRequested: state.isPreviewingVersion
          ? null
          : () => context.read<OcptResourcesBloc>().add(
              const OcptResourcesLocationCreationRequestedEvent(),
            ),
      onAddElementRequested: state.isPreviewingVersion
          ? null
          : (category) => context.read<OcptResourcesBloc>().add(
              OcptResourcesElementCreationRequestedEvent(category: category),
            ),
    );
  }

  /// Builds the shell's `centre`: the selected record's sheet, whichever tab is active, each tab
  /// with its own empty state while nothing is selected there.
  Widget _buildCentre(BuildContext context, OcptResourcesState state) {
    if (state.activeTab == OcptResourcesTab.roles) {
      return _buildRolesCentre(context, state);
    }

    if (state.activeTab == OcptResourcesTab.locations) {
      return _buildLocationsCentre(context, state);
    }

    if (state.activeTab == OcptResourcesTab.elements) {
      return _buildElementsCentre(context, state);
    }

    final selectedPerson = state.selectedPerson;
    if (selectedPerson == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.groups_outlined,
        message: Tr.of(context).resourcesNoPersonSelectedHint,
      );
    }

    final bloc = context.read<OcptResourcesBloc>();

    return OcptPersonSheet(
      key: ValueKey(selectedPerson.id),
      person: selectedPerson,
      isReadOnly: state.isPreviewingVersion,
      fieldValueOf: (field) => _fieldValueOf(state, selectedPerson, field),
      onFieldChanged: (field, rawValue) => bloc.add(
        OcptResourcesPersonFieldChangedEvent(personId: selectedPerson.id, field: field, rawValue: rawValue),
      ),
      onColorChanged: (colorIndex) => bloc.add(
        OcptResourcesPersonColorChangedEvent(personId: selectedPerson.id, colorIndex: colorIndex),
      ),
      onBirthDateChanged: (date) => bloc.add(
        OcptResourcesPersonBirthDateChangedEvent(personId: selectedPerson.id, date: date),
      ),
      onTransportAutonomyChanged: (isTransportAutonomous) => bloc.add(
        OcptResourcesPersonTransportAutonomyChangedEvent(
          personId: selectedPerson.id,
          isTransportAutonomous: isTransportAutonomous,
        ),
      ),
      onImageRightsStatusChanged: (status) => bloc.add(
        OcptResourcesPersonImageRightsStatusChangedEvent(personId: selectedPerson.id, status: status),
      ),
      onImageRightsDateChanged: (date) => bloc.add(
        OcptResourcesPersonImageRightsDateChangedEvent(personId: selectedPerson.id, date: date),
      ),
      onPositionAdded: () => bloc.add(
        OcptResourcesPositionAddedEvent(personId: selectedPerson.id, positionId: "", customLabel: ""),
      ),
      onPositionUpdated: (id, {required positionId, required customLabel}) => bloc.add(
        OcptResourcesPositionUpdatedEvent(id: id, positionId: positionId, customLabel: customLabel),
      ),
      onPositionRemoved: (id) => bloc.add(OcptResourcesPositionRemovedEvent(id: id)),
      onSkillAdded: (label) =>
          bloc.add(OcptResourcesSkillAddedEvent(personId: selectedPerson.id, label: label)),
      onSkillRemoved: (id) => bloc.add(OcptResourcesSkillRemovedEvent(id: id)),
      onUnavailabilityAdded:
          ({
            required startDate,
            required endDate,
            required slot,
            required startMinute,
            required endMinute,
          }) => bloc.add(
            OcptResourcesUnavailabilityAddedEvent(
              personId: selectedPerson.id,
              startDate: startDate,
              endDate: endDate,
              slot: slot,
              startMinute: startMinute,
              endMinute: endMinute,
              reason: "",
            ),
          ),
      onUnavailabilityUpdated:
          (
            id, {
            required startDate,
            required endDate,
            required slot,
            required startMinute,
            required endMinute,
            required reason,
          }) => bloc.add(
            OcptResourcesUnavailabilityUpdatedEvent(
              id: id,
              startDate: startDate,
              endDate: endDate,
              slot: slot,
              startMinute: startMinute,
              endMinute: endMinute,
              reason: reason,
            ),
          ),
      onUnavailabilityRemoved: (id) => bloc.add(OcptResourcesUnavailabilityRemovedEvent(id: id)),
      onDeleteRequested: () => _handleDeletePersonRequested(context, selectedPerson),
    );
  }

  /// [person]'s current value for [field]: a pending edit still sitting in the bloc's debounce
  /// takes priority over the person's own stored value, so typing is never overwritten by an
  /// unrelated reload. Mirrors `OcptShotListMode._fieldValueOf`.
  String _fieldValueOf(OcptResourcesState state, OcptPerson person, OcptPersonField field) {
    final pending = state.pendingFieldEdits[(person.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptPersonField.firstName => person.firstName,
      OcptPersonField.lastName => person.lastName,
      OcptPersonField.email => person.email,
      OcptPersonField.phone => person.phone,
      OcptPersonField.addressLine1 => person.addressLine1,
      OcptPersonField.addressLine2 => person.addressLine2,
      OcptPersonField.postalCode => person.postalCode,
      OcptPersonField.city => person.city,
      OcptPersonField.region => person.region,
      OcptPersonField.country => person.country,
      OcptPersonField.minorNotes => person.minorNotes,
      OcptPersonField.accommodationNotes => person.accommodationNotes,
      OcptPersonField.travelNotes => person.travelNotes,
      OcptPersonField.dietaryNotes => person.dietaryNotes,
      OcptPersonField.allergies => person.allergies,
      OcptPersonField.measurementHeight => person.measurementHeight,
      OcptPersonField.measurementChest => person.measurementChest,
      OcptPersonField.measurementWaist => person.measurementWaist,
      OcptPersonField.measurementHips => person.measurementHips,
      OcptPersonField.sizeTop => person.sizeTop,
      OcptPersonField.sizeBottom => person.sizeBottom,
      OcptPersonField.sizeShoes => person.sizeShoes,
      OcptPersonField.hmcNotes => person.hmcNotes,
      OcptPersonField.notes => person.notes,
    };
  }

  /// Shows the person deletion confirmation dialog, then dispatches the erasure if the user
  /// confirmed it. Mirrors `OcptShotListMode._handleDeleteRequested`.
  Future<void> _handleDeletePersonRequested(BuildContext context, OcptPerson person) async {
    final bloc = context.read<OcptResourcesBloc>();
    final tr = Tr.of(context);
    final name = person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName;

    final confirmed = await OcptPersonDeleteConfirmDialog.show(context, personName: name);
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: person.id));
  }

  /// Builds the roles tab's centre: the selected role's sheet, or the empty state — the one
  /// explaining where roles come from while the cast itself is empty, the one asking for a
  /// selection otherwise, mirroring `resourcesNoPersonSelectedHint`'s tone.
  Widget _buildRolesCentre(BuildContext context, OcptResourcesState state) {
    final tr = Tr.of(context);
    final selectedRole = state.selectedRole;

    if (selectedRole == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.theater_comedy_outlined,
        message: state.roles.isEmpty ? tr.resourcesRolesEmptyHint : tr.resourcesNoRoleSelectedHint,
      );
    }

    final bloc = context.read<OcptResourcesBloc>();
    final castMember = _personOf(state, selectedRole.personId);

    return OcptRoleSheet(
      key: ValueKey(selectedRole.id),
      role: selectedRole,
      castMember: castMember,
      otherRoles: _otherRolesOf(state, selectedRole, castMember),
      people: state.people,
      removedRoleAlert: state.selectedRoleAlert,
      isReadOnly: state.isPreviewingVersion,
      fieldValueOf: (field) => _roleFieldValueOf(state, selectedRole, field),
      onFieldChanged: (field, rawValue) => bloc.add(
        OcptResourcesRoleFieldChangedEvent(
          roleId: selectedRole.id,
          field: field,
          rawValue: rawValue,
        ),
      ),
      onCastChanged: (personId) => bloc.add(
        OcptResourcesRoleCastChangedEvent(roleId: selectedRole.id, personId: personId),
      ),
      onKindChanged: (kind) =>
          bloc.add(OcptResourcesRoleKindChangedEvent(roleId: selectedRole.id, kind: kind)),
      onDeleteRequested: () =>
          bloc.add(OcptResourcesRoleDeletionRequestedEvent(roleId: selectedRole.id)),
      onOrphanedRoleKept: () =>
          bloc.add(OcptResourcesOrphanedRoleKeptEvent(roleId: selectedRole.id)),
      onPersonSheetOpenRequested: (personId) =>
          bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId)),
    );
  }

  /// Builds the locations tab's centre: the selected location's sheet, or the empty state — the one
  /// inviting a first location while there is none, the one asking for a selection otherwise.
  Widget _buildLocationsCentre(BuildContext context, OcptResourcesState state) {
    final tr = Tr.of(context);
    final selectedLocation = state.selectedLocation;

    if (selectedLocation == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.place_outlined,
        message: state.locations.isEmpty
            ? tr.resourcesLocationsEmptyHint
            : tr.resourcesNoLocationSelectedHint,
      );
    }

    final bloc = context.read<OcptResourcesBloc>();

    return OcptLocationSheet(
      key: ValueKey(selectedLocation.id),
      location: selectedLocation,
      contact: _personOf(state, selectedLocation.contactPersonId),
      people: state.people,
      scenes: state.scenes,
      assignedSceneIds: _assignedSceneIdsOf(state),
      suggestedSetIdBySceneId: _suggestedSetIdsOf(state),
      isReadOnly: state.isPreviewingVersion,
      fieldValueOf: (field) => _locationFieldValueOf(state, selectedLocation, field),
      onFieldChanged: (field, rawValue) => bloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: selectedLocation.id,
          field: field,
          rawValue: rawValue,
        ),
      ),
      onColorChanged: (colorIndex) => bloc.add(
        OcptResourcesLocationColorChangedEvent(
          locationId: selectedLocation.id,
          colorIndex: colorIndex,
        ),
      ),
      onPermitStatusChanged: (status) => bloc.add(
        OcptResourcesLocationPermitStatusChangedEvent(
          locationId: selectedLocation.id,
          status: status,
        ),
      ),
      onPermitDateChanged: (date) => bloc.add(
        OcptResourcesLocationPermitDateChangedEvent(locationId: selectedLocation.id, date: date),
      ),
      onContactChanged: (personId) => bloc.add(
        OcptResourcesLocationContactChangedEvent(
          locationId: selectedLocation.id,
          personId: personId,
        ),
      ),
      onPersonSheetOpenRequested: (personId) =>
          bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId)),
      setFieldValueOf: (setId, field) => _setFieldValueOf(state, setId, field),
      onSetFieldChanged: (setId, field, rawValue) => bloc.add(
        OcptResourcesSetFieldChangedEvent(setId: setId, field: field, rawValue: rawValue),
      ),
      onSetAdded: () => bloc.add(OcptResourcesSetAddedEvent(locationId: selectedLocation.id)),
      onSetRemoved: (setId) => bloc.add(OcptResourcesSetRemovedEvent(setId: setId)),
      onSceneAssigned: (sceneId, setId) =>
          bloc.add(OcptResourcesSceneAssignedToSetEvent(sceneId: sceneId, setId: setId)),
      onSceneRemoved: (sceneId, setId) =>
          bloc.add(OcptResourcesSceneRemovedFromSetEvent(sceneId: sceneId, setId: setId)),
      onPhotoAddRequested: () => bloc.add(
        OcptResourcesLocationPhotoAddRequestedEvent(
          locationId: selectedLocation.id,
          fileTypeLabel: tr.resourcesImageFileTypeLabel,
        ),
      ),
      onPhotoRemoved: (assetId) => bloc.add(OcptResourcesAssetRemovedEvent(assetId: assetId)),
      onPermitDocumentPickRequested: () => bloc.add(
        OcptResourcesPermitDocumentPickRequestedEvent(
          locationId: selectedLocation.id,
          fileTypeLabel: tr.resourcesDocumentFileTypeLabel,
        ),
      ),
      onPermitDocumentCleared: () => bloc.add(
        OcptResourcesPermitDocumentClearedEvent(locationId: selectedLocation.id),
      ),
      onAvailabilityUpdated:
          (
            id, {
            required startDate,
            required endDate,
            required weekdays,
            required slot,
            required startMinute,
            required endMinute,
            required kind,
            required note,
          }) => bloc.add(
            OcptResourcesLocationAvailabilityUpdatedEvent(
              id: id,
              startDate: startDate,
              endDate: endDate,
              weekdays: weekdays,
              slot: slot,
              startMinute: startMinute,
              endMinute: endMinute,
              kind: kind,
              note: note,
            ),
          ),
      onAvailabilityAdded:
          ({
            required startDate,
            required endDate,
            required weekdays,
            required slot,
            required startMinute,
            required endMinute,
          }) => bloc.add(
            OcptResourcesLocationAvailabilityAddedEvent(
              locationId: selectedLocation.id,
              startDate: startDate,
              endDate: endDate,
              weekdays: weekdays,
              slot: slot,
              startMinute: startMinute,
              endMinute: endMinute,
              kind: OcptLocationAvailabilityKind.available,
              note: "",
            ),
          ),
      onAvailabilityRemoved: (id) =>
          bloc.add(OcptResourcesLocationAvailabilityRemovedEvent(id: id)),
      onDeleteRequested: () =>
          bloc.add(OcptResourcesLocationDeletionRequestedEvent(locationId: selectedLocation.id)),
    );
  }

  /// Builds the elements tab's centre: the selected element's sheet, or the empty state — the one
  /// inviting a first element while the catalogue is empty, the one asking for a selection
  /// otherwise.
  Widget _buildElementsCentre(BuildContext context, OcptResourcesState state) {
    final tr = Tr.of(context);
    final selectedElement = state.selectedElement;

    if (selectedElement == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.inventory_2_outlined,
        message: state.elements.isEmpty
            ? tr.resourcesElementsEmptyHint
            : tr.resourcesNoElementSelectedHint,
      );
    }

    final bloc = context.read<OcptResourcesBloc>();

    return OcptElementSheet(
      key: ValueKey(selectedElement.id),
      element: selectedElement,
      owner: _personOf(state, selectedElement.ownerPersonId),
      bringer: _personOf(state, selectedElement.broughtByPersonId),
      people: state.people,
      scenes: state.scenes,
      isReadOnly: state.isPreviewingVersion,
      fieldValueOf: (field) => _elementFieldValueOf(state, selectedElement, field),
      onFieldChanged: (field, rawValue) => bloc.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: selectedElement.id,
          field: field,
          rawValue: rawValue,
        ),
      ),
      onCategoryChanged: (category) => bloc.add(
        OcptResourcesElementCategoryChangedEvent(
          elementId: selectedElement.id,
          category: category,
        ),
      ),
      onSourceKindChanged: (sourceKind) => bloc.add(
        OcptResourcesElementSourceKindChangedEvent(
          elementId: selectedElement.id,
          sourceKind: sourceKind,
        ),
      ),
      onOwnerChanged: (personId) => bloc.add(
        OcptResourcesElementOwnerChangedEvent(
          elementId: selectedElement.id,
          personId: personId,
        ),
      ),
      onBringerChanged: (personId) => bloc.add(
        OcptResourcesElementBringerChangedEvent(
          elementId: selectedElement.id,
          personId: personId,
        ),
      ),
      onTrackingFlagChanged: (flag, {required value}) => bloc.add(
        OcptResourcesElementTrackingFlagChangedEvent(
          elementId: selectedElement.id,
          flag: flag,
          value: value,
        ),
      ),
      onSceneAssigned: (sceneId) => bloc.add(
        OcptResourcesSceneAssignedToElementEvent(
          sceneId: sceneId,
          elementId: selectedElement.id,
        ),
      ),
      onLinkUpdated: (id, {required quantity, required notes}) => bloc.add(
        OcptResourcesSceneElementUpdatedEvent(id: id, quantity: quantity, notes: notes),
      ),
      onLinkRemoved: (id) => bloc.add(OcptResourcesSceneElementRemovedEvent(id: id)),
      onDeleteRequested: () =>
          bloc.add(OcptResourcesElementDeletionRequestedEvent(elementId: selectedElement.id)),
      onPersonSheetOpenRequested: (personId) =>
          bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId)),
    );
  }

  /// [element]'s current value for [field]: a pending edit still sitting in the bloc's debounce
  /// takes priority over the element's own stored value, so typing is never overwritten by an
  /// unrelated reload. Mirrors [_fieldValueOf].
  ///
  /// The cost is the field whose stored value is not a string: it is written back as the plain
  /// amount `ocptCostCentsOf` reads, so a field showing `12.50` holds 1250 cents.
  String _elementFieldValueOf(
    OcptResourcesState state,
    OcptElement element,
    OcptElementField field,
  ) {
    final pending = state.pendingElementFieldEdits[(element.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptElementField.name => element.name,
      OcptElementField.code => element.code,
      OcptElementField.subCategory => element.subCategory,
      OcptElementField.quantity => element.quantity,
      OcptElementField.ownerNotes => element.ownerNotes,
      OcptElementField.storageNotes => element.storageNotes,
      OcptElementField.cost => ocptCostTextOf(element.cost),
      OcptElementField.purposeNotes => element.purposeNotes,
      OcptElementField.notes => element.notes,
    };
  }

  /// The ids of every scene already shot in a set, of this location or of another.
  ///
  /// Read across the **whole** project rather than the selected location alone: a scene may be shot
  /// in several sets, so this does not say what picking one would do — it says which scenes are
  /// still waiting for a set of their own, which is what the picker sorts by and what a suggestion
  /// is offered for.
  Set<String> _assignedSceneIdsOf(OcptResourcesState state) => {
    for (final location in state.locations)
      for (final set in location.sets) ...set.sceneIds,
  };

  /// The set each still-unplaced scene is suggested for, keyed by scene id.
  ///
  /// Computed once per build rather than per scene and per set: the suggestion is a property of a
  /// scene's heading against the whole project, not of the set that happens to be drawing it.
  /// Scenes already placed are left out — a suggestion is an offer to fill a hole, never a remark
  /// about an answer the user has already given.
  Map<String, String> _suggestedSetIdsOf(OcptResourcesState state) {
    final assignedSceneIds = _assignedSceneIdsOf(state);
    final suggestions = <String, String>{};

    for (final scene in state.scenes) {
      if (assignedSceneIds.contains(scene.id)) {
        continue;
      }

      final setId = ocptSceneSetSuggestionOf(
        heading: scene.heading,
        locations: state.locations,
      );
      if (setId != null) {
        suggestions[scene.id] = setId;
      }
    }

    return suggestions;
  }

  /// Set [setId]'s current value for [field]: a pending edit still sitting in the bloc's debounce
  /// takes priority over the set's own stored value, exactly as it does for a location's fields.
  String _setFieldValueOf(OcptResourcesState state, String setId, OcptSetField field) {
    final pending = state.pendingSetFieldEdits[(setId, field)];
    if (pending != null) {
      return pending;
    }

    for (final location in state.locations) {
      for (final set in location.sets) {
        if (set.id == setId) {
          return switch (field) {
            OcptSetField.code => set.code,
            OcptSetField.name => set.name,
            OcptSetField.notes => set.notes,
          };
        }
      }
    }

    return "";
  }

  /// [location]'s current value for [field]: a pending edit still sitting in the bloc's debounce
  /// takes priority over the location's own stored value, so typing is never overwritten by an
  /// unrelated reload. Mirrors [_fieldValueOf].
  ///
  /// The two coordinates are the fields whose stored value is not a string: they are read back the
  /// way they were typed rather than reformatted, so a field showing `45.76` was written `45.76`.
  String _locationFieldValueOf(
    OcptResourcesState state,
    OcptLocation location,
    OcptLocationField field,
  ) {
    final pending = state.pendingLocationFieldEdits[(location.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptLocationField.name => location.name,
      OcptLocationField.addressLine1 => location.addressLine1,
      OcptLocationField.addressLine2 => location.addressLine2,
      OcptLocationField.postalCode => location.postalCode,
      OcptLocationField.city => location.city,
      OcptLocationField.region => location.region,
      OcptLocationField.country => location.country,
      OcptLocationField.latitude => location.latitude?.toString() ?? "",
      OcptLocationField.longitude => location.longitude?.toString() ?? "",
      OcptLocationField.contactNotes => location.contactNotes,
      OcptLocationField.permitLabel => location.permitLabel,
      OcptLocationField.parkingNotes => location.parkingNotes,
      OcptLocationField.powerNotes => location.powerNotes,
      OcptLocationField.facilitiesNotes => location.facilitiesNotes,
      OcptLocationField.constraintsNotes => location.constraintsNotes,
      OcptLocationField.notes => location.notes,
    };
  }

  /// The person [personId] names, or null when it is null or names nobody in the loaded address
  /// book (a stale reference from a snapshot rebuilt underneath).
  OcptPerson? _personOf(OcptResourcesState state, String? personId) {
    if (personId == null) {
      return null;
    }

    for (final person in state.people) {
      if (person.id == personId) {
        return person;
      }
    }

    return null;
  }

  /// The other roles [castMember] holds beside [role], in display order, or empty while [role] is
  /// uncast or its cast member holds only this one.
  List<OcptRole> _otherRolesOf(OcptResourcesState state, OcptRole role, OcptPerson? castMember) {
    if (castMember == null) {
      return const [];
    }

    return [
      for (final other in state.roles)
        if (other.id != role.id && other.personId == castMember.id) other,
    ];
  }

  /// [role]'s current value for [field]: a pending edit still sitting in the bloc's debounce takes
  /// priority over the role's own stored value, so typing is never overwritten by an unrelated
  /// reload. Mirrors [_fieldValueOf].
  String _roleFieldValueOf(OcptResourcesState state, OcptRole role, OcptRoleField field) {
    final pending = state.pendingRoleFieldEdits[(role.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptRoleField.name => role.name,
      OcptRoleField.castingNotes => role.castingNotes,
    };
  }

  /// Builds the right dock, the shell's `rightPanel`, or null while the dock is closed.
  Widget? _buildRightDock(BuildContext context, OcptResourcesState state) {
    if (state.rightDockTab == null) {
      return null;
    }

    return OcptResourcesRightDock(
      versionsChild: _buildVersionsPanel(context, state),
      onClose: () =>
          context.read<OcptResourcesBloc>().add(const OcptResourcesRightDockClosedEvent()),
    );
  }

  /// Builds the band naming the version being previewed, the shell's `banner`, or null while the
  /// working copy is on screen.
  Widget? _buildReadOnlyBanner(BuildContext context, OcptResourcesState state) {
    final previewedVersion = state.previewedVersion;
    if (previewedVersion == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      onForkRequested: () => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () => context.read<OcptResourcesBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
    );
  }

  /// Builds the right dock's `Versions` tab: the working copy's own card and the project's named
  /// versions, the same panel every other mode's dock hosts, wired to the events
  /// `MixinOcptProjectVersionsBloc` handles.
  Widget _buildVersionsPanel(BuildContext context, OcptResourcesState state) =>
      OcptProjectVersionsPanel(
        versions: state.projectVersions,
        previewedVersionId: state.previewedVersionId,
        workingCopy: state.workingCopy,
        versionPendingDeletionId: state.versionPendingDeletionId,
        versionPendingRestoreId: state.versionPendingRestoreId,
        versionPendingRenameId: state.versionPendingRenameId,
        onCreateRequested: () => _requestVersionCreation(context),
        onPreviewRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
        ),
        onPreviewExitRequested: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionPreviewExitRequestedEvent(),
        ),
        onRestoreRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
        ),
        onRestoreCancelled: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionRestoreCancelledEvent(),
        ),
        onRestoreConfirmed: (version) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRestoreConfirmedEvent(
            versionId: version.id,
            safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
          ),
        ),
        onDeleteRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
        ),
        onDeleteCancelled: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionDeletionCancelledEvent(),
        ),
        onDeleteConfirmed: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
        ),
        onRenameRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRenameRequestedEvent(versionId: versionId),
        ),
        onRenameCancelled: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionRenameCancelledEvent(),
        ),
        onRenameConfirmed: (versionId, name, note) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
        ),
      );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptResourcesBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Applies bloc-driven effects onto the page: the live dock fractions, and the transient write
  /// error / version notice SnackBars.
  void _onStateChanged(BuildContext context, OcptResourcesState state) {
    // Pushes the bloc's persisted fractions (the initial load, or "Reset panel layout") onto the
    // live controller; a no-op once a drag's own end-of-gesture event brings the bloc back in
    // sync with the value the controller already holds.
    _dockLayoutController.syncFromPersisted(
      leftFraction: state.leftDockFraction,
      rightFraction: state.rightDockFraction,
    );

    if (state.hasWriteError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).resourcesWriteError)));
      context.read<OcptResourcesBloc>().add(const OcptResourcesWriteErrorDismissedEvent());
    }

    final ioNotice = state.ioNotice;
    if (ioNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
      context.read<OcptResourcesBloc>().add(const OcptResourcesIoNoticeDismissedEvent());
    }

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
      context.read<OcptResourcesBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }
  }

  /// Maps [notice] to its localized, user-facing message, mirroring
  /// `OcptShotListMode._ioNoticeMessage`.
  String _ioNoticeMessage(BuildContext context, OcptResourcesIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptResourcesIoNoticeKind.xlsxExportSucceeded => tr.resourcesExportXlsxSuccessMessage(
        notice.path ?? "",
      ),
      OcptResourcesIoNoticeKind.xlsxExportFailed => tr.resourcesExportXlsxError,
    };
  }
}
