// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// A set ("décor") inside a location. See `OcptSetsTable`'s own doc comment for why a location
/// commonly holds several of these.
class OcptSet extends Equatable {
  /// The stable, unique id of this set (a UUID).
  final String id;

  /// The location this set belongs to.
  final String locationId;

  /// The short code a breakdown margin has room for (e.g. `A`, `B`), empty until assigned.
  final String code;

  /// The set's display name (e.g. "Cuisine").
  final String name;

  /// Free-form notes about this set.
  final String notes;

  /// The ids of the scenes shot in this set, in the screenplay's own order.
  ///
  /// The `scene_sets` links seen from the set they point at. A scene belongs to **at most one**
  /// set (see `OcptLocationsService.assignSceneToSet`), so nothing here can name the same scene
  /// twice, and no set list needs to explain what two sets claiming one scene would mean.
  final List<String> sceneIds;

  /// Class constructor
  const OcptSet({
    required this.id,
    required this.locationId,
    required this.code,
    required this.name,
    required this.notes,
    required this.sceneIds,
  });

  /// Builds an [OcptSet] from its stored [row] and the ids of the [sceneIds] shot in it.
  factory OcptSet.fromRow({required OcptSetRow row, required List<String> sceneIds}) => OcptSet(
    id: row.id,
    locationId: row.locationId,
    code: row.code,
    name: row.name,
    notes: row.notes,
    sceneIds: sceneIds,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptSet(id: $id, name: $name)";

  /// Object properties
  @override
  List<Object?> get props => [id, locationId, code, name, notes, sceneIds];
}
