// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// A character of the film and the person cast to play them, if any.
///
/// `number` is the role's `sortKey`-ordered rank shown in the UI (1-based), derived at read time
/// exactly as `OcptShot.code` is: it is never stored, so it is always in step with insertions,
/// deletions and reorders, and it is why `fromRow` takes it as a parameter rather than reading it
/// off the row — the row alone knows nothing about its rank among its siblings.
class OcptRole extends Equatable {
  /// The stable, unique id of this role (a UUID).
  final String id;

  /// The screenplay this role belongs to.
  final String screenplayId;

  /// The character's name. Owned by `OcptRoleIndexService` while [isFromScreenplay] is true.
  final String name;

  /// The person cast in this role, or null while it is uncast.
  final String? personId;

  /// Whether this is a speaking role, a silent role or an extra.
  final OcptRoleKind kind;

  /// Whether [name] is owned by the screenplay reconciliation rather than typed by the user.
  final bool isFromScreenplay;

  /// The name this character had when it stopped being found in the screenplay, or null while it
  /// is still present.
  final String? orphanedName;

  /// Casting notes for this role, free text.
  final String castingNotes;

  /// This role's 1-based rank in `sortKey` order. See the class doc comment.
  final int number;

  /// Class constructor
  const OcptRole({
    required this.id,
    required this.screenplayId,
    required this.name,
    required this.personId,
    required this.kind,
    required this.isFromScreenplay,
    required this.orphanedName,
    required this.castingNotes,
    required this.number,
  });

  /// Builds an [OcptRole] from its stored [row] and its 1-based [number] in `sortKey` order.
  factory OcptRole.fromRow({required OcptRoleRow row, required int number}) => OcptRole(
    id: row.id,
    screenplayId: row.screenplayId,
    name: row.name,
    personId: row.personId,
    kind: row.kind,
    isFromScreenplay: row.isFromScreenplay,
    orphanedName: row.orphanedName,
    castingNotes: row.castingNotes,
    number: number,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptRole(id: $id, number: $number, name: $name)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    screenplayId,
    name,
    personId,
    kind,
    isFromScreenplay,
    orphanedName,
    castingNotes,
    number,
  ];
}
