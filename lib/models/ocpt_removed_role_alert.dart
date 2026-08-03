// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// A role the screenplay no longer names as a speaking character, but whose casting and notes are
/// kept: what the resources mode's removed-role banner is built from.
///
/// Mirrors `OcptShotRemovedCharacterAlert` in shape (a static [buildAll] over already-loaded data,
/// consumed by a banner offering the same two ways out), but not in how it is computed: a shot's
/// characters are compared against the screenplay's current cast every time, because they are
/// authored independently of it, while a role's [OcptRole.orphanedName] is already the outcome of
/// that comparison — `OcptRoleIndexService.reconcile` sets it once, at save time — so [buildAll]
/// here only has to read it back off the roles already loaded, not recompute it.
class OcptRemovedRoleAlert extends Equatable {
  /// The id of the orphaned role.
  final String roleId;

  /// The character's name, as it read in the screenplay before it stopped being found there.
  final String characterName;

  /// Class constructor
  const OcptRemovedRoleAlert({required this.roleId, required this.characterName});

  /// Every alert of [roles]: one per role whose `OcptRole.orphanedName` is set, in the order
  /// [roles] lists them.
  static List<OcptRemovedRoleAlert> buildAll(List<OcptRole> roles) => [
    for (final role in roles)
      if (role.orphanedName != null)
        OcptRemovedRoleAlert(roleId: role.id, characterName: role.orphanedName!),
  ];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptRemovedRoleAlert(roleId: $roleId, characterName: $characterName)";

  /// Object properties
  @override
  List<Object?> get props => [roleId, characterName];
}
