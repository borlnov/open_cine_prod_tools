// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// The whole resources mode's read, in one object: [people], [roles], [locations] and [elements],
/// plus the five counts the mode's status bar shows — `N people · N roles · N positions ·
/// N locations · N elements`.
///
/// Built the same way `OcptShotListSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. Each list comes from its own service
/// (`OcptPeopleService.loadPeople`, `OcptRoleIndexService.loadRoles`,
/// `OcptLocationsService.loadLocations`, `OcptElementsService.loadElements`); combining the four
/// calls into this one object is the job of whichever mode reads them, once it exists.
class OcptResourcesSnapshot extends Equatable {
  /// The whole address book, in display order.
  final List<OcptPerson> people;

  /// The whole cast, in display order.
  final List<OcptRole> roles;

  /// Every location, in display order.
  final List<OcptLocation> locations;

  /// Every element of the catalogue, in display order.
  final List<OcptElement> elements;

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
    required this.peopleCount,
    required this.roleCount,
    required this.positionCount,
    required this.locationCount,
    required this.elementCount,
  });

  /// Builds an [OcptResourcesSnapshot] from [people], [roles], [locations] and [elements],
  /// deriving the five counts from them.
  factory OcptResourcesSnapshot.build({
    required List<OcptPerson> people,
    required List<OcptRole> roles,
    required List<OcptLocation> locations,
    required List<OcptElement> elements,
  }) => OcptResourcesSnapshot(
    people: people,
    roles: roles,
    locations: locations,
    elements: elements,
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
    peopleCount,
    roleCount,
    positionCount,
    locationCount,
    elementCount,
  ];
}
