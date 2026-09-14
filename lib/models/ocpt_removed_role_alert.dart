// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// A role the screenplay no longer names as a speaking character, but whose casting and notes are
/// kept: the "orphaned" variant of `OcptRoleAlertBanner`
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`, decision 4), shown wherever the
/// role is — the resources mode's role sheet and, above the shot table, the shot list.
///
/// A role's [OcptRole.orphanedName] is already the outcome of the comparison against the
/// screenplay's current cast — `OcptRoleIndexService.reconcile` sets it once, at save time — so
/// [buildAll] here only has to read it back off the roles already loaded, not recompute it.
class OcptRemovedRoleAlert extends Equatable {
  /// The id of the orphaned role.
  final String roleId;

  /// The character's name, as it read in the screenplay before it stopped being found there.
  final String characterName;

  /// Class constructor
  const OcptRemovedRoleAlert({required this.roleId, required this.characterName});

  /// [role]'s own alert, or null while it is still found in the screenplay.
  static OcptRemovedRoleAlert? of(OcptRole role) {
    final orphanedName = role.orphanedName;
    if (orphanedName == null) {
      return null;
    }

    return OcptRemovedRoleAlert(roleId: role.id, characterName: orphanedName);
  }

  /// Every alert of [roles]: one per role whose `OcptRole.orphanedName` is set, in the order
  /// [roles] lists them.
  static List<OcptRemovedRoleAlert> buildAll(List<OcptRole> roles) => [
    for (final role in roles)
      if (OcptRemovedRoleAlert.of(role) case final alert?) alert,
  ];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptRemovedRoleAlert(roleId: $roleId, characterName: $characterName)";

  /// Object properties
  @override
  List<Object?> get props => [roleId, characterName];
}
