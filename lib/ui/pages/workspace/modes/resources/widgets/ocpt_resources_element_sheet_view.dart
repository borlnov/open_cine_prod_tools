// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';

/// The resources mode's centre while the elements tab is active: the selected element's
/// [OcptElementSheet], or the empty state — the one inviting a first element while the catalogue is
/// empty, the one asking for a selection otherwise.
///
/// The sheet sits inside a [BlocBuilder] on [OcptResourcesElementsBloc] alone, so a keystroke in
/// one of its fields redraws the sheet and not the shell around it. Deleting the element is only
/// *asked*, through [onDeleteRequested]: the mode owns the confirmation dialog.
class OcptResourcesElementSheetView extends StatelessWidget {
  /// The mode's state, which the selected element and the shared lists are read from.
  final OcptResourcesState state;

  /// Called when the user asked to delete the selected element.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptResourcesElementSheetView({
    super.key,
    required this.state,
    required this.onDeleteRequested,
  });

  /// Build the resources element sheet view as a [BlocBuilder].
  @override
  Widget build(BuildContext context) {
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
    final elementsBloc = context.read<OcptResourcesElementsBloc>();

    return BlocBuilder<OcptResourcesElementsBloc, OcptResourcesElementsState>(
      builder: (context, elementsState) => OcptElementSheet(
        key: ValueKey(selectedElement.id),
        element: selectedElement,
        owner: state.personOf(selectedElement.ownerPersonId),
        bringer: state.personOf(selectedElement.broughtByPersonId),
        people: state.people,
        roles: state.roles,
        scenes: state.scenes,
        currencyCode: state.currencyCode,
        isReadOnly: state.isPreviewingVersion,
        fieldValueOf: (field) => _elementFieldValueOf(elementsState, selectedElement, field),
        onPhotoPickRequested: () => elementsBloc.add(
          OcptResourcesElementPhotoPickRequestedEvent(
            elementId: selectedElement.id,
            fileTypeLabel: tr.resourcesImageFileTypeLabel,
          ),
        ),
        onPhotoCleared: () =>
            elementsBloc.add(OcptResourcesElementPhotoClearedEvent(elementId: selectedElement.id)),
        onFieldChanged: (field, rawValue) => elementsBloc.add(
          OcptResourcesElementFieldChangedEvent(
            elementId: selectedElement.id,
            field: field,
            rawValue: rawValue,
          ),
        ),
        onCategoryChanged: (category) => elementsBloc.add(
          OcptResourcesElementCategoryChangedEvent(
            elementId: selectedElement.id,
            category: category,
          ),
        ),
        onSourceKindChanged: (sourceKind) => elementsBloc.add(
          OcptResourcesElementSourceKindChangedEvent(
            elementId: selectedElement.id,
            sourceKind: sourceKind,
          ),
        ),
        onOwnerChanged: (personId) => elementsBloc.add(
          OcptResourcesElementOwnerChangedEvent(elementId: selectedElement.id, personId: personId),
        ),
        onBringerChanged: (personId) => elementsBloc.add(
          OcptResourcesElementBringerChangedEvent(
            elementId: selectedElement.id,
            personId: personId,
          ),
        ),
        onTrackingFlagChanged: (flag, {required value}) => elementsBloc.add(
          OcptResourcesElementTrackingFlagChangedEvent(
            elementId: selectedElement.id,
            flag: flag,
            value: value,
          ),
        ),
        onSceneAssigned: (sceneId) => elementsBloc.add(
          OcptResourcesSceneAssignedToElementEvent(sceneId: sceneId, elementId: selectedElement.id),
        ),
        onLinkUpdated: (id, {required quantity, required notes}) => elementsBloc.add(
          OcptResourcesSceneElementUpdatedEvent(id: id, quantity: quantity, notes: notes),
        ),
        onLinkRemoved: (id) => elementsBloc.add(OcptResourcesSceneElementRemovedEvent(id: id)),
        onDeleteRequested: onDeleteRequested,
        onPersonSheetOpenRequested: (personId) =>
            bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId)),
        onRoleSheetOpenRequested: (roleId) =>
            bloc.add(OcptResourcesRoleSheetOpenRequestedEvent(roleId: roleId)),
      ),
    );
  }

  /// [element]'s current value for [field]: a pending edit still sitting in the bloc's debounce
  /// takes priority over the element's own stored value, so typing is never overwritten by an
  /// unrelated reload. Mirrors `OcptResourcesPersonSheetView`'s own lookup.
  ///
  /// The cost is the field whose stored value is not a string: it is written back as the plain
  /// amount `ocptCostCentsOf` reads, so a field showing `12.50` holds 1250 cents.
  String _elementFieldValueOf(
    OcptResourcesElementsState state,
    OcptElement element,
    OcptElementField field,
  ) {
    final pending = state.pendingElementFieldEdits[(element.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptElementField.name => element.name,
      OcptElementField.subCategory => element.subCategory,
      OcptElementField.quantity => element.quantity,
      OcptElementField.ownerNotes => element.ownerNotes,
      OcptElementField.storageNotes => element.storageNotes,
      OcptElementField.cost => ocptCostTextOf(element.cost),
      OcptElementField.purposeNotes => element.purposeNotes,
      OcptElementField.notes => element.notes,
    };
  }
}
