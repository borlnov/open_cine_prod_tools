// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';

/// One person seen for one part: a `role_candidates` row joined with the [OcptPerson] it names.
///
/// **The person travels with the candidacy**, rather than being resolved from an id at read time
/// the way `OcptElement` leaves its owner to the UI: a candidates card shows a face, a name and a
/// phone number for each row it draws, so every reader of this model needs the person anyway, and
/// a candidacy whose person cannot be resolved is not shown at all
/// (`OcptRoleCandidatesService.loadCandidatesByRoleId` leaves it out, exactly as a set's link onto
/// a vanished scene is left out).
///
/// [OcptRoleCandidateStatus.retained] is the one status that means something beyond this row: it is
/// what wrote `roles.personId`, and only `OcptRoleCandidatesService` ever writes it — see that
/// service for the rule the two tables are kept in step by.
class OcptRoleCandidate extends Equatable {
  /// The stable, unique id of this candidacy (a UUID).
  final String id;

  /// The part this person is seen for. → `OcptRole`
  final String roleId;

  /// The person seen, joined in: the address book row this candidacy points at.
  final OcptPerson person;

  /// Where this person stands in the casting of this part.
  final OcptRoleCandidateStatus status;

  /// When this person was seen, or null while nobody has said. Typed by hand — see
  /// `OcptRoleCandidatesTable.auditionedOn`.
  final DateTime? auditionedOn;

  /// The impressions kept on this person for this part, free text.
  final String notes;

  /// Class constructor
  const OcptRoleCandidate({
    required this.id,
    required this.roleId,
    required this.person,
    required this.status,
    required this.auditionedOn,
    required this.notes,
  });

  /// Builds an [OcptRoleCandidate] from its stored [row] and the [person] its `personId` resolves
  /// to.
  factory OcptRoleCandidate.fromRow({
    required OcptRoleCandidateRow row,
    required OcptPerson person,
  }) => OcptRoleCandidate(
    id: row.id,
    roleId: row.roleId,
    person: person,
    status: row.status,
    auditionedOn: row.auditionedOn,
    notes: row.notes,
  );

  /// Whether this candidacy is the one that cast the part.
  bool get isRetained => status == OcptRoleCandidateStatus.retained;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptRoleCandidate(id: $id, roleId: $roleId, status: $status)";

  /// Object properties
  @override
  List<Object?> get props => [id, roleId, person, status, auditionedOn, notes];
}
