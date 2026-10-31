// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/events/resources_base_event.dart';

/// The events about elements.
sealed class OcptResourcesElementsEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesElementsEvent();
}

/// Requests referencing element [elementId]'s photo, replacing whichever one it referenced before.
/// See `OcptResourcesLocationPhotoAddRequestedEvent` for [fileTypeLabel].
class OcptResourcesElementPhotoPickRequestedEvent extends OcptResourcesElementsEvent {
  /// The id of the element the photo is referenced for.
  final String elementId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptResourcesElementPhotoPickRequestedEvent({
    required this.elementId,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, fileTypeLabel];
}

/// Drops element [elementId]'s reference to its photo. The file itself is never touched.
class OcptResourcesElementPhotoClearedEvent extends OcptResourcesElementsEvent {
  /// The id of the element whose photo reference is dropped.
  final String elementId;

  /// Class constructor
  const OcptResourcesElementPhotoClearedEvent({required this.elementId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId];
}

/// Requests creating a new, blank element at the end of the catalogue, then selecting it: the left
/// dock's `+ Add an element` action.
///
/// It carries the category the new element lands in, which the action asks for up front: an element
/// with no category would have to sit under a "no category" heading of its own in a list whose only
/// structure is the categories, and picking one afterwards would move it out from under the user's
/// eyes.
class OcptResourcesElementCreationRequestedEvent extends OcptResourcesElementsEvent {
  /// The category the new element belongs to.
  final OcptElementCategory category;

  /// Class constructor
  const OcptResourcesElementCreationRequestedEvent({required this.category});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, category];
}

/// Requests deleting element [elementId], dispatched once `OcptResourcesDeleteConfirmDialog` has
/// already confirmed it. Clears the selection when [elementId] was the selected element, and drops
/// any pending field edit that still targeted it.
class OcptResourcesElementDeletionRequestedEvent extends OcptResourcesElementsEvent {
  /// The id of the element to delete.
  final String elementId;

  /// Class constructor
  const OcptResourcesElementDeletionRequestedEvent({required this.elementId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId];
}

/// Records the raw text just typed into [field] of element [elementId], written once the field-edit
/// debounce elapses.
class OcptResourcesElementFieldChangedEvent extends OcptResourcesElementsEvent {
  /// The id of the element being edited.
  final String elementId;

  /// The field being edited.
  final OcptElementField field;

  /// The raw text the field now holds.
  final String rawValue;

  /// Class constructor
  const OcptResourcesElementFieldChangedEvent({
    required this.elementId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, field, rawValue];
}

/// Sets element [elementId]'s category, written immediately.
class OcptResourcesElementCategoryChangedEvent extends OcptResourcesElementsEvent {
  /// The id of the element whose category changes.
  final String elementId;

  /// The category now picked.
  final OcptElementCategory category;

  /// Class constructor
  const OcptResourcesElementCategoryChangedEvent({required this.elementId, required this.category});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, category];
}

/// Sets where element [elementId] comes from, written immediately.
class OcptResourcesElementSourceKindChangedEvent extends OcptResourcesElementsEvent {
  /// The id of the element whose provenance changes.
  final String elementId;

  /// The provenance now picked.
  final OcptElementSourceKind sourceKind;

  /// Class constructor
  const OcptResourcesElementSourceKindChangedEvent({
    required this.elementId,
    required this.sourceKind,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, sourceKind];
}

/// Sets who owns element [elementId] (or clears it), written immediately.
class OcptResourcesElementOwnerChangedEvent extends OcptResourcesElementsEvent {
  /// The id of the element whose owner changes.
  final String elementId;

  /// The id of the person who owns it, or null to clear it — the owner is then said in
  /// `ownerNotes` alone, which is how an organisation is named.
  final String? personId;

  /// Class constructor
  const OcptResourcesElementOwnerChangedEvent({required this.elementId, required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, personId];
}

/// Sets who brings element [elementId] to set (or clears it), written immediately.
class OcptResourcesElementBringerChangedEvent extends OcptResourcesElementsEvent {
  /// The id of the element whose bringer changes.
  final String elementId;

  /// The id of the person who brings it, or null to clear it.
  final String? personId;

  /// Class constructor
  const OcptResourcesElementBringerChangedEvent({required this.elementId, required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, personId];
}

/// Sets one of element [elementId]'s three tracking flags, written immediately.
///
/// One event for the three of them rather than three events differing only in their name: they are
/// the same gesture on the same card, and `OcptElementTrackingFlag` is what says which box was
/// ticked.
class OcptResourcesElementTrackingFlagChangedEvent extends OcptResourcesElementsEvent {
  /// The id of the element whose flag changes.
  final String elementId;

  /// The flag being ticked or unticked.
  final OcptElementTrackingFlag flag;

  /// What the flag now holds.
  final bool value;

  /// Class constructor
  const OcptResourcesElementTrackingFlagChangedEvent({
    required this.elementId,
    required this.flag,
    required this.value,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, flag, value];
}

/// Says element [elementId] is needed in scene [sceneId], written immediately.
class OcptResourcesSceneAssignedToElementEvent extends OcptResourcesElementsEvent {
  /// The id of the scene needing the element.
  final String sceneId;

  /// The id of the element it needs.
  final String elementId;

  /// Class constructor
  const OcptResourcesSceneAssignedToElementEvent({required this.sceneId, required this.elementId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, elementId];
}

/// Updates the quantity and the notes of the scene ↔ element link [id], written immediately.
///
/// Carries both fields at once because the row that reports it holds both: it debounces its own
/// typing locally and reports the whole link, exactly as an unavailability's row does.
class OcptResourcesSceneElementUpdatedEvent extends OcptResourcesElementsEvent {
  /// The id of the link being updated.
  final String id;

  /// How many of the element this scene needs.
  final String quantity;

  /// What this scene has to say about its need for the element.
  final String notes;

  /// Class constructor
  const OcptResourcesSceneElementUpdatedEvent({
    required this.id,
    required this.quantity,
    required this.notes,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id, quantity, notes];
}

/// Removes the scene ↔ element link [id], written immediately.
class OcptResourcesSceneElementRemovedEvent extends OcptResourcesElementsEvent {
  /// The id of the link to remove.
  final String id;

  /// Class constructor
  const OcptResourcesSceneElementRemovedEvent({required this.id});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id];
}

/// Links role [roleId] to element [elementId], written immediately.
///
/// Dispatched by the role sheet's things card. The write is `OcptElementsService`'s, not
/// `OcptRoleIndexService`'s: the row is a link onto an element, and one service owns both halves of
/// it — see `OcptRoleElementsTable`.
class OcptResourcesElementLinkedToRoleEvent extends OcptResourcesElementsEvent {
  /// The id of the role needing the element.
  final String roleId;

  /// The id of the element it needs.
  final String elementId;

  /// Class constructor
  const OcptResourcesElementLinkedToRoleEvent({required this.roleId, required this.elementId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId, elementId];
}

/// Updates the notes of the role ↔ element link [id], written immediately.
///
/// Carries the whole note rather than a keystroke: the row that reports it debounces its own typing
/// locally, exactly as the scenes card's own row does.
class OcptResourcesRoleElementUpdatedEvent extends OcptResourcesElementsEvent {
  /// The id of the link being updated.
  final String id;

  /// What this role has to say about its use of the element.
  final String notes;

  /// Class constructor
  const OcptResourcesRoleElementUpdatedEvent({required this.id, required this.notes});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id, notes];
}

/// Removes the role ↔ element link [id], written immediately.
///
/// The **element itself is untouched**: it stays in the catalogue, and so does every other link
/// onto it. This says only that this role no longer wears, carries or is made up with it.
class OcptResourcesRoleElementRemovedEvent extends OcptResourcesElementsEvent {
  /// The id of the link to remove.
  final String id;

  /// Class constructor
  const OcptResourcesRoleElementRemovedEvent({required this.id});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id];
}

/// Fired by the field-edit debounce timer `OcptResourcesElementFieldChangedEvent` (re)starts, once
/// it elapses with no further edit. Not meant to be dispatched by a widget directly.
class OcptResourcesElementsFieldEditFlushRequestedEvent extends OcptResourcesElementsEvent {
  /// Class constructor
  const OcptResourcesElementsFieldEditFlushRequestedEvent();
}
