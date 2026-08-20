// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';

/// The whole resources mode's read, in one object: [people], [roles], [locations] and [elements],
/// [candidatesByRoleId], the [scenes] a set is picked from, plus the five counts the mode's status
/// bar shows — `N people · N roles · N positions · N locations · N elements`.
///
/// Built the same way `OcptShotListSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. Each list comes from its own service
/// (`OcptPeopleService.loadPeople`, `OcptRoleIndexService.loadRoles`,
/// `OcptLocationsService.loadLocations` and `.loadScenes`, `OcptElementsService.loadElements`,
/// `OcptRoleCandidatesService.loadCandidatesByRoleId`); combining the calls into this one object is
/// the job of the mode that reads them.
class OcptResourcesSnapshot extends Equatable {
  /// The whole address book, in display order.
  final List<OcptPerson> people;

  /// The whole cast, in display order.
  final List<OcptRole> roles;

  /// Every location, in display order.
  final List<OcptLocation> locations;

  /// Every element of the catalogue, in display order.
  final List<OcptElement> elements;

  /// Every live candidacy of the project, grouped by `roleId`, each group in its own `sortKey`
  /// order — exactly `OcptRoleCandidatesService.loadCandidatesByRoleId`'s own return value.
  ///
  /// No count of its own in the status bar: a candidacy is not a resource of its own, it is what the
  /// roles tab's pill and a role's own candidates card read to say where a part's casting stands,
  /// and `ocptCastRoleCount` already reports the one number about casting the status bar shows.
  final Map<String, List<OcptRoleCandidate>> candidatesByRoleId;

  /// Every scene of the project's primary screenplay, in source order.
  ///
  /// Not a resource of its own: it is what the locations tab picks from when it says which scene a
  /// set is shot in, and what names the scenes a set already holds. No count of it is shown — the
  /// status bar counts what this mode owns, and the screenplay's scenes belong to the screenplay.
  final List<OcptSceneRef> scenes;

  /// `people.length`.
  final int peopleCount;

  /// `roles.length`.
  final int roleCount;

  /// The total number of crew position assignments across [people].
  final int positionCount;

  /// `locations.length`.
  final int locationCount;

  /// `elements.length`.
  final int elementCount;

  /// Class constructor
  const OcptResourcesSnapshot({
    required this.people,
    required this.roles,
    required this.locations,
    required this.elements,
    required this.candidatesByRoleId,
    required this.scenes,
    required this.peopleCount,
    required this.roleCount,
    required this.positionCount,
    required this.locationCount,
    required this.elementCount,
  });

  /// Builds an [OcptResourcesSnapshot] from [people], [roles], [locations], [elements],
  /// [candidatesByRoleId] and [scenes], deriving the five counts from them.
  factory OcptResourcesSnapshot.build({
    required List<OcptPerson> people,
    required List<OcptRole> roles,
    required List<OcptLocation> locations,
    required List<OcptElement> elements,
    required Map<String, List<OcptRoleCandidate>> candidatesByRoleId,
    required List<OcptSceneRef> scenes,
  }) => OcptResourcesSnapshot(
    people: people,
    roles: roles,
    locations: locations,
    elements: elements,
    candidatesByRoleId: candidatesByRoleId,
    scenes: scenes,
    peopleCount: people.length,
    roleCount: roles.length,
    positionCount: people.fold(0, (sum, person) => sum + person.positions.length),
    locationCount: locations.length,
    elementCount: elements.length,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptResourcesSnapshot(peopleCount: $peopleCount, roleCount: $roleCount, "
      "positionCount: $positionCount, locationCount: $locationCount, "
      "elementCount: $elementCount)";

  /// Object properties
  @override
  List<Object?> get props => [
    people,
    roles,
    locations,
    elements,
    candidatesByRoleId,
    scenes,
    peopleCount,
    roleCount,
    positionCount,
    locationCount,
    elementCount,
  ];
}
