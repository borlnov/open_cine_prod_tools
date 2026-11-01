// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_set_suggestion.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';

/// The resources mode's centre while the locations tab is active: the selected location's
/// [OcptLocationSheet], or the empty state — the one inviting a first location while there is none,
/// the one asking for a selection otherwise.
///
/// The sheet sits inside a [BlocBuilder] on [OcptResourcesLocationsBloc] alone, so a keystroke in
/// one of its fields redraws the sheet and not the shell around it. Deleting the location is only
/// *asked*, through [onDeleteRequested]: the mode owns the confirmation dialog.
class OcptResourcesLocationSheetView extends StatelessWidget {
  /// The mode's state, which the selected location and the shared lists are read from.
  final OcptResourcesState state;

  /// Called when the user asked to delete the selected location.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptResourcesLocationSheetView({
    super.key,
    required this.state,
    required this.onDeleteRequested,
  });

  /// Build the resources location sheet view as a [BlocBuilder].
  @override
  Widget build(BuildContext context) {
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
    final locationsBloc = context.read<OcptResourcesLocationsBloc>();

    return BlocBuilder<OcptResourcesLocationsBloc, OcptResourcesLocationsState>(
      builder: (context, locationsState) => OcptLocationSheet(
        key: ValueKey(selectedLocation.id),
        location: selectedLocation,
        contact: state.personOf(selectedLocation.contactPersonId),
        people: state.people,
        scenes: state.scenes,
        otherLocations: _otherLocationsOf(state, selectedLocation.id),
        assignedSceneIds: _assignedSceneIdsOf(state),
        suggestedSetIdBySceneId: _suggestedSetIdsOf(state),
        setIdsWithPlan: state.setIdsWithPlan,
        isReadOnly: state.isPreviewingVersion,
        fieldValueOf: (field) => _locationFieldValueOf(locationsState, selectedLocation, field),
        onFieldChanged: (field, rawValue) => locationsBloc.add(
          OcptResourcesLocationFieldChangedEvent(
            locationId: selectedLocation.id,
            field: field,
            rawValue: rawValue,
          ),
        ),
        onColorChanged: (colorIndex) => locationsBloc.add(
          OcptResourcesLocationColorChangedEvent(
            locationId: selectedLocation.id,
            colorIndex: colorIndex,
          ),
        ),
        onPermitStatusChanged: (status) => locationsBloc.add(
          OcptResourcesLocationPermitStatusChangedEvent(
            locationId: selectedLocation.id,
            status: status,
          ),
        ),
        onPermitDateChanged: (date) => locationsBloc.add(
          OcptResourcesLocationPermitDateChangedEvent(locationId: selectedLocation.id, date: date),
        ),
        onContactChanged: (personId) => locationsBloc.add(
          OcptResourcesLocationContactChangedEvent(
            locationId: selectedLocation.id,
            personId: personId,
          ),
        ),
        onPersonSheetOpenRequested: (personId) =>
            bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId)),
        setFieldValueOf: (setId, field) => _setFieldValueOf(state, locationsState, setId, field),
        onSetFieldChanged: (setId, field, rawValue) => locationsBloc.add(
          OcptResourcesSetFieldChangedEvent(setId: setId, field: field, rawValue: rawValue),
        ),
        onSetAdded: () =>
            locationsBloc.add(OcptResourcesSetAddedEvent(locationId: selectedLocation.id)),
        onSetRemoved: (setId) => locationsBloc.add(OcptResourcesSetRemovedEvent(setId: setId)),
        onSetLocationChanged: (setId, locationId) => locationsBloc.add(
          OcptResourcesSetLocationChangedEvent(setId: setId, locationId: locationId),
        ),
        onSceneAssigned: (sceneId, setId) =>
            locationsBloc.add(OcptResourcesSceneAssignedToSetEvent(sceneId: sceneId, setId: setId)),
        onSceneRemoved: (sceneId, setId) => locationsBloc.add(
          OcptResourcesSceneRemovedFromSetEvent(sceneId: sceneId, setId: setId),
        ),
        onOpenSetInShotListRequested: (setId) =>
            bloc.add(OcptResourcesOpenSetInShotListRequestedEvent(setId: setId)),
        onPhotoAddRequested: () => locationsBloc.add(
          OcptResourcesLocationPhotoAddRequestedEvent(
            locationId: selectedLocation.id,
            fileTypeLabel: tr.resourcesImageFileTypeLabel,
          ),
        ),
        onPhotoRemoved: (assetId) =>
            locationsBloc.add(OcptResourcesAssetRemovedEvent(assetId: assetId)),
        onPermitDocumentPickRequested: () => locationsBloc.add(
          OcptResourcesPermitDocumentPickRequestedEvent(
            locationId: selectedLocation.id,
            fileTypeLabel: tr.resourcesDocumentFileTypeLabel,
          ),
        ),
        onPermitDocumentCleared: () => locationsBloc.add(
          OcptResourcesPermitDocumentClearedEvent(locationId: selectedLocation.id),
        ),
        onPermitDocumentValidFromChanged: (date) => locationsBloc.add(
          OcptResourcesAssetValidFromChangedEvent(
            assetId: selectedLocation.permitDocument!.id,
            date: date,
          ),
        ),
        onPermitDocumentValidUntilChanged: (date) => locationsBloc.add(
          OcptResourcesAssetValidUntilChangedEvent(
            assetId: selectedLocation.permitDocument!.id,
            date: date,
          ),
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
            }) => locationsBloc.add(
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
            }) => locationsBloc.add(
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
            locationsBloc.add(OcptResourcesLocationAvailabilityRemovedEvent(id: id)),
        onDeleteRequested: onDeleteRequested,
      ),
    );
  }

  /// Get every location of the project other than [locationId], `(id, name)`, in the order the list
  /// panel shows them — the destinations the sets card's own move control offers.
  List<(String, String)> _otherLocationsOf(OcptResourcesState state, String locationId) => [
    for (final location in state.locations)
      if (location.id != locationId) (location.id, location.name),
  ];

  /// Get the ids of every scene already shot in a set, of this location or of another.
  ///
  /// Read across the **whole** project rather than the selected location alone: a scene may be shot
  /// in several sets, so this does not say what picking one would do — it says which scenes are
  /// still waiting for a set of their own, which is what the picker sorts by and what a suggestion
  /// is offered for.
  Set<String> _assignedSceneIdsOf(OcptResourcesState state) => {
    for (final location in state.locations)
      for (final set in location.sets) ...set.sceneIds,
  };

  /// Get the set each still-unplaced scene is suggested for, keyed by scene id.
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

      final setId = ocptSceneSetSuggestionOf(heading: scene.heading, locations: state.locations);
      if (setId != null) {
        suggestions[scene.id] = setId;
      }
    }

    return suggestions;
  }

  /// Set [setId]'s current value for [field]: a pending edit still sitting in the bloc's debounce
  /// takes priority over the set's own stored value, exactly as it does for a location's fields.
  String _setFieldValueOf(
    OcptResourcesState state,
    OcptResourcesLocationsState locationsState,
    String setId,
    OcptSetField field,
  ) {
    final pending = locationsState.pendingSetFieldEdits[(setId, field)];
    if (pending != null) {
      return pending;
    }

    for (final location in state.locations) {
      for (final set in location.sets) {
        if (set.id == setId) {
          return switch (field) {
            OcptSetField.name => set.name,
            OcptSetField.notes => set.notes,
          };
        }
      }
    }

    return "";
  }

  /// Get [location]'s current value for [field]: a pending edit still sitting in the bloc's
  /// debounce
  /// takes priority over the location's own stored value, so typing is never overwritten by an
  /// unrelated reload. Mirrors `OcptResourcesPersonSheetView`'s own lookup.
  ///
  /// The two coordinates are the fields whose stored value is not a string: they are read back the
  /// way they were typed rather than reformatted, so a field showing `45.76` was written `45.76`.
  String _locationFieldValueOf(
    OcptResourcesLocationsState state,
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
}
