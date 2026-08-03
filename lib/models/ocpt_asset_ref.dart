// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';

/// A binary file the resources mode refers to by path, mirroring `OcptAssetsTable` — see its own
/// doc comment and `docs/adr/0013-binary-assets-referenced-by-path.md` for why this never carries
/// bytes.
///
/// No service of this step loads or writes `assets` rows yet: the four services this step ships
/// (people, roles, locations, elements) only carry the nullable asset ids their own table already
/// has (`OcptPerson.photoAssetId`, `OcptLocation.permitAssetId`, …). This model exists so a later
/// milestone's asset picker and thumbnails have a shape to build on without inventing one then.
class OcptAssetRef extends Equatable {
  /// The stable, unique id of this asset (a UUID).
  final String id;

  /// What subject this asset illustrates or documents.
  final OcptAssetKind kind;

  /// The absolute path of the referenced file on the machine that recorded it. See the class doc
  /// comment: a "file not found" marker, not an error, is the expected outcome of a stale one.
  final String path;

  /// A user-facing label for this asset, free text.
  final String label;

  /// The date and time at which this asset reference was added.
  final DateTime addedAt;

  /// The person this asset belongs to, or null.
  final String? personId;

  /// The location this asset belongs to, or null.
  final String? locationId;

  /// The element this asset belongs to, or null.
  final String? elementId;

  /// Class constructor
  const OcptAssetRef({
    required this.id,
    required this.kind,
    required this.path,
    required this.label,
    required this.addedAt,
    required this.personId,
    required this.locationId,
    required this.elementId,
  });

  /// Builds an [OcptAssetRef] from its stored [row].
  factory OcptAssetRef.fromRow(OcptAssetRow row) => OcptAssetRef(
    id: row.id,
    kind: row.kind,
    path: row.path,
    label: row.label,
    addedAt: row.addedAt,
    personId: row.personId,
    locationId: row.locationId,
    elementId: row.elementId,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptAssetRef(id: $id, kind: $kind, path: $path)";

  /// Object properties
  @override
  List<Object?> get props => [id, kind, path, label, addedAt, personId, locationId, elementId];
}
