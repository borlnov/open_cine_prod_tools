// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// A named lead time a shooting day carries — see `OcptShootingDayGroupsTable`'s own doc comment.
class OcptShootingDayGroup extends Equatable {
  /// The stable, unique id of this group (a UUID).
  final String id;

  /// The day this group belongs to.
  final String shootingDayId;

  /// This group's own label ("Figuration", "Équipe technique"), free text.
  final String label;

  /// How many minutes before the moment a member of this group is needed they have to be there.
  final int leadMinutes;

  /// Class constructor
  const OcptShootingDayGroup({
    required this.id,
    required this.shootingDayId,
    required this.label,
    required this.leadMinutes,
  });

  /// Builds an [OcptShootingDayGroup] from its stored [row].
  factory OcptShootingDayGroup.fromRow(OcptShootingDayGroupRow row) => OcptShootingDayGroup(
    id: row.id,
    shootingDayId: row.shootingDayId,
    label: row.label,
    leadMinutes: row.leadMinutes,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayGroup(id: $id, shootingDayId: $shootingDayId, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [id, shootingDayId, label, leadMinutes];
}
