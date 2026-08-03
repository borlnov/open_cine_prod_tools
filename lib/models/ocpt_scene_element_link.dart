// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One *dépouillement* link seen from the element it points at: the scene needing it, how many of
/// it that scene needs, and whatever the scene has to say about the need.
///
/// A `scene_elements` row rather than a scene id alone, unlike `OcptSet.sceneIds`: a set holds a
/// scene or it does not, while an element is needed in a given quantity, for a given reason, in
/// each scene it appears in — "2 verres, dont un cassé" is a fact about scene 12, not about the
/// glasses. The link's own id travels with it because that is what an update and a removal are
/// addressed to.
class OcptSceneElementLink extends Equatable {
  /// The stable, unique id of this link (a UUID).
  final String id;

  /// The scene needing the element. → `OcptSceneRef`
  final String sceneId;

  /// How many of the element this scene needs, overriding `OcptElement.quantity` for this scene
  /// alone. Free text, for the same reason the element's own quantity is.
  final String quantity;

  /// Free-form notes about this scene's need for the element.
  final String notes;

  /// Class constructor
  const OcptSceneElementLink({
    required this.id,
    required this.sceneId,
    required this.quantity,
    required this.notes,
  });

  /// Builds an [OcptSceneElementLink] from its stored [row].
  factory OcptSceneElementLink.fromRow(OcptSceneElementRow row) => OcptSceneElementLink(
    id: row.id,
    sceneId: row.sceneId,
    quantity: row.quantity,
    notes: row.notes,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptSceneElementLink(id: $id, sceneId: $sceneId)";

  /// Object properties
  @override
  List<Object?> get props => [id, sceneId, quantity, notes];
}
