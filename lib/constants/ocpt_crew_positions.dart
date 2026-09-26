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
  /// Retiring a position removes it from this list without reusing its id for something else.
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

/// The id of the `director` position, the one entry of [ocptCrewPositions] the app looks up by name.
///
/// A call sheet and a shooting plan both print `A film by <name>`, and that name is not a column of
/// the project: it is read off whoever the address book already says holds this position. Naming the
/// id here rather than typing the string at that call site is what keeps the lookup and the
/// catalogue entry from drifting apart silently — a renamed id would otherwise print no director at
/// all, with nothing failing to say so.
const String ocptDirectorPositionId = 'director';

/// The crew positions of a French film production, covering the functions of the *Convention
/// collective nationale de la production cinématographique* (IDCC 3097, titre II) — deliberately
/// **without** the construction sub-trades (carpenters, plasterers, painters, locksmiths… and
/// their chief/sub-chief variants), summarised instead by `constructionManager` and
/// `constructionCrew`: this catalogue names who a call sheet or a person's own sheet needs to name,
/// not every classification the convention itself lists.
///
/// A person is assigned to zero or more of these through `person_positions`; the catalogue itself
/// is not a database table, since it never needs a `sortKey` or a tombstone of its own — it changes
/// with an app release, not with a project. **An id is never renamed or reused** once shipped (see
/// [OcptCrewPosition.id]); a label may be reworded freely. Entries are kept **grouped by
/// department, in [OcptCrewDepartment]'s own declaration order**, since the picker dialog and every
/// printed catalogue walk this list in order — a new position is inserted into its department's own
/// run rather than merely appended, which is safe precisely because nothing but [OcptCrewPosition.id]
/// is ever read back by identity.
const List<OcptCrewPosition> ocptCrewPositions = [
  // Direction
  OcptCrewPosition(
    id: ocptDirectorPositionId,
    labelKey: 'resourcesCrewPositionDirector',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'firstAssistantDirector',
    labelKey: 'resourcesCrewPositionFirstAssistantDirector',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'secondAssistantDirector',
    labelKey: 'resourcesCrewPositionSecondAssistantDirector',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'assistantDirectorTrainee',
    labelKey: 'resourcesCrewPositionAssistantDirectorTrainee',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'scriptSupervisor',
    labelKey: 'resourcesCrewPositionScriptSupervisor',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'assistantScriptSupervisor',
    labelKey: 'resourcesCrewPositionAssistantScriptSupervisor',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'dialogueCoach',
    labelKey: 'resourcesCrewPositionDialogueCoach',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'technicalAdvisor',
    labelKey: 'resourcesCrewPositionTechnicalAdvisor',
    department: OcptCrewDepartment.direction,
  ),
  OcptCrewPosition(
    id: 'secondUnitDirector',
    labelKey: 'resourcesCrewPositionSecondUnitDirector',
    department: OcptCrewDepartment.direction,
  ),

  // Production
  OcptCrewPosition(
    id: 'productionManager',
    labelKey: 'resourcesCrewPositionProductionManager',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'lineProducer',
    labelKey: 'resourcesCrewPositionLineProducer',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'productionAdministrator',
    labelKey: 'resourcesCrewPositionProductionAdministrator',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'productionAccountant',
    labelKey: 'resourcesCrewPositionProductionAccountant',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'assistantProductionAccountant',
    labelKey: 'resourcesCrewPositionAssistantProductionAccountant',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'productionSecretary',
    labelKey: 'resourcesCrewPositionProductionSecretary',
    department: OcptCrewDepartment.production,
  ),
  OcptCrewPosition(
    id: 'productionAssistant',
    labelKey: 'resourcesCrewPositionProductionAssistant',
    department: OcptCrewDepartment.production,
  ),

  // Unit & locations
  OcptCrewPosition(
    id: 'unitManager',
    labelKey: 'resourcesCrewPositionUnitManager',
    department: OcptCrewDepartment.unit,
  ),
  OcptCrewPosition(
    id: 'assistantUnitManager',
    labelKey: 'resourcesCrewPositionAssistantUnitManager',
    department: OcptCrewDepartment.unit,
  ),
  OcptCrewPosition(
    id: 'locationManager',
    labelKey: 'resourcesCrewPositionLocationManager',
    department: OcptCrewDepartment.unit,
  ),
  OcptCrewPosition(
    id: 'unitAssistant',
    labelKey: 'resourcesCrewPositionUnitAssistant',
    department: OcptCrewDepartment.unit,
  ),

  // Casting & extras
  OcptCrewPosition(
    id: 'castingDirector',
    labelKey: 'resourcesCrewPositionCastingDirector',
    department: OcptCrewDepartment.castingAndExtras,
  ),
  OcptCrewPosition(
    id: 'firstCastingAssistant',
    labelKey: 'resourcesCrewPositionFirstCastingAssistant',
    department: OcptCrewDepartment.castingAndExtras,
  ),
  OcptCrewPosition(
    id: 'extrasCoordinator',
    labelKey: 'resourcesCrewPositionExtrasCoordinator',
    department: OcptCrewDepartment.castingAndExtras,
  ),
  OcptCrewPosition(
    id: 'extrasCoordinatorAssistant',
    labelKey: 'resourcesCrewPositionExtrasCoordinatorAssistant',
    department: OcptCrewDepartment.castingAndExtras,
  ),
  OcptCrewPosition(
    id: 'childWrangler',
    labelKey: 'resourcesCrewPositionChildWrangler',
    department: OcptCrewDepartment.castingAndExtras,
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
    id: 'specialisedCameraOperator',
    labelKey: 'resourcesCrewPositionSpecialisedCameraOperator',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'firstAssistantCamera',
    labelKey: 'resourcesCrewPositionFirstAssistantCamera',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'secondAssistantCamera',
    labelKey: 'resourcesCrewPositionSecondAssistantCamera',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'videoAssistTechnician',
    labelKey: 'resourcesCrewPositionVideoAssistTechnician',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'remoteCameraTechnician',
    labelKey: 'resourcesCrewPositionRemoteCameraTechnician',
    department: OcptCrewDepartment.image,
  ),
  OcptCrewPosition(
    id: 'stillsPhotographer',
    labelKey: 'resourcesCrewPositionStillsPhotographer',
    department: OcptCrewDepartment.image,
  ),

  // Electric & grip
  OcptCrewPosition(
    id: 'gaffer',
    labelKey: 'resourcesCrewPositionGaffer',
    department: OcptCrewDepartment.electricAndGrip,
  ),
  OcptCrewPosition(
    id: 'bestBoyElectric',
    labelKey: 'resourcesCrewPositionBestBoyElectric',
    department: OcptCrewDepartment.electricAndGrip,
  ),
  OcptCrewPosition(
    id: 'electrician',
    labelKey: 'resourcesCrewPositionElectrician',
    department: OcptCrewDepartment.electricAndGrip,
  ),
  OcptCrewPosition(
    id: 'generatorOperator',
    labelKey: 'resourcesCrewPositionGeneratorOperator',
    department: OcptCrewDepartment.electricAndGrip,
  ),
  OcptCrewPosition(
    id: 'keyGrip',
    labelKey: 'resourcesCrewPositionKeyGrip',
    department: OcptCrewDepartment.electricAndGrip,
  ),
  OcptCrewPosition(
    id: 'bestBoyGrip',
    labelKey: 'resourcesCrewPositionBestBoyGrip',
    department: OcptCrewDepartment.electricAndGrip,
  ),
  OcptCrewPosition(
    id: 'grip',
    labelKey: 'resourcesCrewPositionGrip',
    department: OcptCrewDepartment.electricAndGrip,
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
    id: 'productionDesigner',
    labelKey: 'resourcesCrewPositionProductionDesigner',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'firstAssistantArtDirector',
    labelKey: 'resourcesCrewPositionFirstAssistantArtDirector',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'secondAssistantArtDirector',
    labelKey: 'resourcesCrewPositionSecondAssistantArtDirector',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'thirdAssistantArtDirector',
    labelKey: 'resourcesCrewPositionThirdAssistantArtDirector',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'setDecorator',
    labelKey: 'resourcesCrewPositionSetDecorator',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'leadSetDresser',
    labelKey: 'resourcesCrewPositionLeadSetDresser',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'setDresser',
    labelKey: 'resourcesCrewPositionSetDresser',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'propsMaster',
    labelKey: 'resourcesCrewPositionPropsMaster',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'onSetProps',
    labelKey: 'resourcesCrewPositionOnSetProps',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'setDressingProps',
    labelKey: 'resourcesCrewPositionSetDressingProps',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'setIllustrator',
    labelKey: 'resourcesCrewPositionSetIllustrator',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'setGraphicDesigner',
    labelKey: 'resourcesCrewPositionSetGraphicDesigner',
    department: OcptCrewDepartment.artDepartment,
  ),
  OcptCrewPosition(
    id: 'modelMaker',
    labelKey: 'resourcesCrewPositionModelMaker',
    department: OcptCrewDepartment.artDepartment,
  ),

  // Construction
  OcptCrewPosition(
    id: 'constructionManager',
    labelKey: 'resourcesCrewPositionConstructionManager',
    department: OcptCrewDepartment.construction,
  ),
  OcptCrewPosition(
    id: 'constructionCrew',
    labelKey: 'resourcesCrewPositionConstructionCrew',
    department: OcptCrewDepartment.construction,
  ),

  // Costume
  OcptCrewPosition(
    id: 'costumeCreator',
    labelKey: 'resourcesCrewPositionCostumeCreator',
    department: OcptCrewDepartment.costume,
  ),
  OcptCrewPosition(
    id: 'keyCostumer',
    labelKey: 'resourcesCrewPositionKeyCostumer',
    department: OcptCrewDepartment.costume,
  ),
  OcptCrewPosition(
    id: 'costumeDesigner',
    labelKey: 'resourcesCrewPositionCostumeDesigner',
    department: OcptCrewDepartment.costume,
  ),
  OcptCrewPosition(
    id: 'costumeWorkshopSupervisor',
    labelKey: 'resourcesCrewPositionCostumeWorkshopSupervisor',
    department: OcptCrewDepartment.costume,
  ),
  OcptCrewPosition(
    id: 'firstCostumeAssistant',
    labelKey: 'resourcesCrewPositionFirstCostumeAssistant',
    department: OcptCrewDepartment.costume,
  ),
  OcptCrewPosition(
    id: 'dresser',
    labelKey: 'resourcesCrewPositionDresser',
    department: OcptCrewDepartment.costume,
  ),
  OcptCrewPosition(
    id: 'costumeMaker',
    labelKey: 'resourcesCrewPositionCostumeMaker',
    department: OcptCrewDepartment.costume,
  ),
  OcptCrewPosition(
    id: 'costumeDyer',
    labelKey: 'resourcesCrewPositionCostumeDyer',
    department: OcptCrewDepartment.costume,
  ),

  // Hair & make-up
  OcptCrewPosition(
    id: 'keyMakeupArtist',
    labelKey: 'resourcesCrewPositionKeyMakeupArtist',
    department: OcptCrewDepartment.hairAndMakeUp,
  ),
  OcptCrewPosition(
    id: 'makeupArtist',
    labelKey: 'resourcesCrewPositionMakeupArtist',
    department: OcptCrewDepartment.hairAndMakeUp,
  ),
  OcptCrewPosition(
    id: 'assistantMakeupArtist',
    labelKey: 'resourcesCrewPositionAssistantMakeupArtist',
    department: OcptCrewDepartment.hairAndMakeUp,
  ),
  OcptCrewPosition(
    id: 'keyHairStylist',
    labelKey: 'resourcesCrewPositionKeyHairStylist',
    department: OcptCrewDepartment.hairAndMakeUp,
  ),
  OcptCrewPosition(
    id: 'hairStylist',
    labelKey: 'resourcesCrewPositionHairStylist',
    department: OcptCrewDepartment.hairAndMakeUp,
  ),

  // Special effects
  OcptCrewPosition(
    id: 'specialEffectsSupervisor',
    labelKey: 'resourcesCrewPositionSpecialEffectsSupervisor',
    department: OcptCrewDepartment.specialEffects,
  ),
  OcptCrewPosition(
    id: 'specialEffectsAssistant',
    labelKey: 'resourcesCrewPositionSpecialEffectsAssistant',
    department: OcptCrewDepartment.specialEffects,
  ),
  OcptCrewPosition(
    id: 'animatronicsTechnician',
    labelKey: 'resourcesCrewPositionAnimatronicsTechnician',
    department: OcptCrewDepartment.specialEffects,
  ),

  // Editing & post-production
  OcptCrewPosition(
    id: 'editor',
    labelKey: 'resourcesCrewPositionEditor',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'firstAssistantEditor',
    labelKey: 'resourcesCrewPositionFirstAssistantEditor',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'secondAssistantEditor',
    labelKey: 'resourcesCrewPositionSecondAssistantEditor',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'postProductionCoordinator',
    labelKey: 'resourcesCrewPositionPostProductionCoordinator',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'supervisingSoundEditor',
    labelKey: 'resourcesCrewPositionSupervisingSoundEditor',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'assistantSoundEditor',
    labelKey: 'resourcesCrewPositionAssistantSoundEditor',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'rerecordingMixer',
    labelKey: 'resourcesCrewPositionRerecordingMixer',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'assistantMixer',
    labelKey: 'resourcesCrewPositionAssistantMixer',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'foleyArtist',
    labelKey: 'resourcesCrewPositionFoleyArtist',
    department: OcptCrewDepartment.postProduction,
  ),
  OcptCrewPosition(
    id: 'assistantFoleyArtist',
    labelKey: 'resourcesCrewPositionAssistantFoleyArtist',
    department: OcptCrewDepartment.postProduction,
  ),
];
