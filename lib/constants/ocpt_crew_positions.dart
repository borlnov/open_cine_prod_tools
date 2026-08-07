// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';

/// One entry of the [ocptCrewPositions] catalogue: a crew position a call sheet can print.
class OcptCrewPosition {
  /// A stable code identifying this position (e.g. `director`, `soundEngineer`).
  ///
  /// **Never localised, and never renamed once shipped**: `person_positions.positionId` stores it
  /// verbatim, and the schedule mode references it per time slot — renaming an id would silently
  /// detach every row already pointing at it from the position it used to mean.
  /// Retiring a position removes it from this list without reusing its id for something else;
  /// adding a new one only ever appends.
  final String id;

  /// The name of the ARB key (the generated `Tr` class exposes it as a getter of the same name)
  /// this position's label is localised under.
  ///
  /// A plain [String] rather than a `Tr` lookup: `lib/constants/` must stay free of `Tr`, so the
  /// ARB entries themselves and the call site that resolves this key into a label are left to the
  /// milestone that builds the resources mode UI.
  final String labelKey;

  /// The department this position belongs to, for grouping the catalogue in the UI.
  final OcptCrewDepartment department;

  /// Class constructor
  const OcptCrewPosition({required this.id, required this.labelKey, required this.department});
}

/// The crew positions the reference call sheets print, covering direction, image, sound, the art
/// department, hair/make-up/costume and production.
///
/// A person is assigned to zero or more of these through `person_positions`; the catalogue itself
/// is not a database table, since it never needs a `sortKey` or a tombstone of its own — it changes
/// with an app release, not with a project.
const List<OcptCrewPosition> ocptCrewPositions = [
  // Direction
  OcptCrewPosition(
    id: 'director',
    labelKey: 'resourcesCrewPositionDirector',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'firstAssistantDirector',
    labelKey: 'resourcesCrewPositionFirstAssistantDirector',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'scriptSupervisor',
    labelKey: 'resourcesCrewPositionScriptSupervisor',
    department: OcptCrewDepartment.direction,
  ),

  // Image
  OcptCrewPosition(
    id: 'directorOfPhotography',
    labelKey: 'resourcesCrewPositionDirectorOfPhotography',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'cameraOperator',
    labelKey: 'resourcesCrewPositionCameraOperator',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'firstAssistantCamera',
    labelKey: 'resourcesCrewPositionFirstAssistantCamera',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'gaffer',
    labelKey: 'resourcesCrewPositionGaffer',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'electrician',
    labelKey: 'resourcesCrewPositionElectrician',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'grip',
    labelKey: 'resourcesCrewPositionGrip',
    department: OcptCrewDepartment.image,
  ),

  // Sound
  OcptCrewPosition(
    id: 'soundEngineer',
    labelKey: 'resourcesCrewPositionSoundEngineer',
    department: OcptCrewDepartment.sound,
  ),
  OcptCrewPosition(
    id: 'boomOperator',
    labelKey: 'resourcesCrewPositionBoomOperator',
    department: OcptCrewDepartment.sound,
  ),

  // Art department
  OcptCrewPosition(
    id: 'setDecorator',
    labelKey: 'resourcesCrewPositionSetDecorator',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'propsMaster',
    labelKey: 'resourcesCrewPositionPropsMaster',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'setDresser',
    labelKey: 'resourcesCrewPositionSetDresser',
    department: OcptCrewDepartment.artDepartment,
  ),

  // Hair, make-up and costume
  OcptCrewPosition(
    id: 'makeupArtist',
    labelKey: 'resourcesCrewPositionMakeupArtist',
    department: OcptCrewDepartment.hmc,
  ),
  OcptCrewPosition(
    id: 'hairStylist',
    labelKey: 'resourcesCrewPositionHairStylist',
    department: OcptCrewDepartment.hmc,
  ),
  OcptCrewPosition(
    id: 'costumeDesigner',
    labelKey: 'resourcesCrewPositionCostumeDesigner',
    department: OcptCrewDepartment.hmc,
  ),

  // Production
  OcptCrewPosition(
    id: 'productionManager',
    labelKey: 'resourcesCrewPositionProductionManager',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'productionAssistant',
    labelKey: 'resourcesCrewPositionProductionAssistant',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'lineProducer',
    labelKey: 'resourcesCrewPositionLineProducer',
    department: OcptCrewDepartment.production,
  ),
];
