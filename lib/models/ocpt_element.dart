// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';

/// Anything that must be present on a given shooting day and is not a person. See
/// `OcptElementsTable`'s own doc comment for why one table covers every department.
///
/// Deliberately not joined with the person its [ownerPersonId]/[broughtByPersonId] may point at:
/// the elements board shows every element beside the people list in the same
/// `OcptResourcesSnapshot`, so resolving a name from an id is a read-time join the UI performs
/// over the two lists it already has, not something this model duplicates.
class OcptElement extends Equatable {
  /// The stable, unique id of this element (a UUID).
  final String id;

  /// The top-level category this element belongs to.
  final OcptElementCategory category;

  /// A production's own finer grouping within [category], free text.
  final String subCategory;

  /// The element's display name.
  final String name;

  /// The short label a breakdown margin has room for, free text.
  final String code;

  /// How many of this element are needed. Free text — see `OcptElementsTable.quantity`.
  final String quantity;

  /// Where this element comes from, or is going to.
  final OcptElementSourceKind sourceKind;

  /// Who owns this element, when they are in the address book. → `OcptPerson`
  final String? ownerPersonId;

  /// Who owns this element, free text.
  final String ownerNotes;

  /// Who brings this element to set. → `OcptPerson`
  final String? broughtByPersonId;

  /// Where this element is stored until the shoot, free text.
  final String storageNotes;

  /// Whether this element is secured (owned, borrowed, rented or bought).
  final bool isSecured;

  /// Whether this element is ready for the shoot.
  final bool isReadyForShoot;

  /// Whether this element has been returned after the shoot.
  final bool isReturned;

  /// The cost of this element, in cents, or null while unknown.
  final int? cost;

  /// Why this element is needed, free text.
  final String purposeNotes;

  /// Free-form notes about this element.
  final String notes;

  /// This element's photo, or null while there is none. → `OcptAssetRef`
  final String? photoAssetId;

  /// The scenes this element is needed in, in the screenplay's own order.
  ///
  /// The `scene_elements` links seen from the element they point at, each carrying the quantity and
  /// the notes that scene alone has for it. A link onto a scene the screenplay no longer has is
  /// left out rather than shown (see `OcptElementsService.loadElements`), exactly as a set's own
  /// scenes are.
  final List<OcptSceneElementLink> sceneLinks;

  /// Class constructor
  const OcptElement({
    required this.id,
    required this.category,
    required this.subCategory,
    required this.name,
    required this.code,
    required this.quantity,
    required this.sourceKind,
    required this.ownerPersonId,
    required this.ownerNotes,
    required this.broughtByPersonId,
    required this.storageNotes,
    required this.isSecured,
    required this.isReadyForShoot,
    required this.isReturned,
    required this.cost,
    required this.purposeNotes,
    required this.notes,
    required this.photoAssetId,
    required this.sceneLinks,
  });

  /// Builds an [OcptElement] from its stored [row] and the [sceneLinks] pointing at it.
  factory OcptElement.fromRow({
    required OcptElementRow row,
    required List<OcptSceneElementLink> sceneLinks,
  }) => OcptElement(
    id: row.id,
    category: row.category,
    subCategory: row.subCategory,
    name: row.name,
    code: row.code,
    quantity: row.quantity,
    sourceKind: row.sourceKind,
    ownerPersonId: row.ownerPersonId,
    ownerNotes: row.ownerNotes,
    broughtByPersonId: row.broughtByPersonId,
    storageNotes: row.storageNotes,
    isSecured: row.isSecured,
    isReadyForShoot: row.isReadyForShoot,
    isReturned: row.isReturned,
    cost: row.cost,
    purposeNotes: row.purposeNotes,
    notes: row.notes,
    photoAssetId: row.photoAssetId,
    sceneLinks: sceneLinks,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptElement(id: $id, name: $name, category: $category)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    category,
    subCategory,
    name,
    code,
    quantity,
    sourceKind,
    ownerPersonId,
    ownerNotes,
    broughtByPersonId,
    storageNotes,
    isSecured,
    isReadyForShoot,
    isReturned,
    cost,
    purposeNotes,
    notes,
    photoAssetId,
    sceneLinks,
  ];
}
