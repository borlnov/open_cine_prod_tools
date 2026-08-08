// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One `role_elements` link seen from the element it points at: the role needing it, and whatever
/// that role has to say about the need.
///
/// **Carried by the element rather than by the role, both ways round.** The role sheet's own card
/// is what the user adds to and removes from, and it still reads these links: it scans the elements
/// catalogue for the ones naming its role. That is deliberate — one service loads the table, one
/// model carries it, and the two sheets cannot end up disagreeing about what a role wears. It also
/// gives the role's card the order it wants for free: the catalogue's own `sortKey` order, grouped
/// by category at read time.
///
/// `OcptSceneElementLink`'s sibling, minus the quantity: a role wears the coat or they do not, while
/// a scene may need two glasses. The link's own id travels with it because that is what an update
/// and a removal are addressed to.
class OcptRoleElementLink extends Equatable {
  /// The stable, unique id of this link (a UUID).
  final String id;

  /// The role needing the element. → `OcptRole`
  final String roleId;

  /// Free-form notes about this role's use of the element.
  final String notes;

  /// Class constructor
  const OcptRoleElementLink({required this.id, required this.roleId, required this.notes});

  /// Builds an [OcptRoleElementLink] from its stored [row].
  factory OcptRoleElementLink.fromRow(OcptRoleElementRow row) =>
      OcptRoleElementLink(id: row.id, roleId: row.roleId, notes: row.notes);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptRoleElementLink(id: $id, roleId: $roleId)";

  /// Object properties
  @override
  List<Object?> get props => [id, roleId, notes];
}
