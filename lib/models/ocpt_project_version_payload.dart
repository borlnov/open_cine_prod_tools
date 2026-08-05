// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';

/// The whole state of a project at the moment a version was created: what
/// `OcptProjectVersionsService` captures, what `OcptProjectVersionCodec` serializes into
/// `project_versions.payload`, and what a restore writes back.
///
/// Every list here holds the table's rows **verbatim, tombstones and primary keys included**:
///
/// - the keys, because a restore must never re-derive the scene index from the restored text.
///   That would mint fresh scene UUIDs and silently break every `shots.sceneId` and
///   `shot_coverages.sceneId` reference carried by this very payload — the single subtlest
///   constraint of the whole feature;
/// - the tombstones, because a payload holding only the live rows would, on restore, resurrect
///   everything the user had deleted since (`docs/adr/0010-sync-ready-data-model-prerequisites.md`
///   makes a deletion a row like any other).
///
/// The `screenplay_snapshots` rows are deliberately **not** part of this: snapshots are a rolling
/// safety net rather than history, and copying thirty full screenplay texts into every version
/// would multiply the project file's size for nothing — stated here so the missing field reads as a
/// decision rather than an oversight.
///
/// `local_erasures` is deliberately **not** part of this either, and for the opposite reason: it
/// must never travel in a payload. It is local, never synchronised, and its whole job is to survive
/// a restore of a version captured before an erasure — carrying it here would let that very restore
/// rewind the fact that the erasure ever happened. See `ocpt_local_erasures_table.dart` and
/// `OcptProjectVersionsService`'s restore path, which reads it straight from the database instead.
class OcptProjectVersionPayload extends Equatable {
  /// The `screenplays` rows of the project.
  final List<OcptScreenplayRow> screenplays;

  /// The `scenes` rows of the project: the scene index as it stood, never recomputed on restore.
  final List<OcptSceneRow> scenes;

  /// The `shots` rows of the project.
  final List<OcptShotRow> shots;

  /// The `shot_characters` rows of the project.
  final List<OcptShotCharacterRow> shotCharacters;

  /// The `shot_coverages` rows of the project.
  final List<OcptShotCoverageRow> shotCoverages;

  /// The `people` rows of the project: the address book, tombstones included.
  final List<OcptPersonRow> people;

  /// The `person_positions` rows of the project.
  final List<OcptPersonPositionRow> personPositions;

  /// The `person_skills` rows of the project.
  final List<OcptPersonSkillRow> personSkills;

  /// The `person_unavailabilities` rows of the project.
  final List<OcptPersonUnavailabilityRow> personUnavailabilities;

  /// The `roles` rows of the project.
  final List<OcptRoleRow> roles;

  /// The `locations` rows of the project.
  final List<OcptLocationRow> locations;

  /// The `location_availabilities` rows of the project.
  final List<OcptLocationAvailabilityRow> locationAvailabilities;

  /// The `sets` rows of the project.
  final List<OcptSetRow> sets;

  /// The `scene_sets` rows of the project.
  final List<OcptSceneSetRow> sceneSets;

  /// The `elements` rows of the project.
  final List<OcptElementRow> elements;

  /// The `scene_elements` rows of the project.
  final List<OcptSceneElementRow> sceneElements;

  /// The `assets` rows of the project: the binary asset references, never the bytes they point at
  /// (`docs/adr/0013-binary-assets-referenced-by-path.md`). Restoring a version restores the
  /// reference, and the file it names may now be dangling — a normal state, not an error.
  final List<OcptAssetRow> assets;

  /// The `breakdown_tags` rows of the project: the passages tagged during the breakdown pass,
  /// anchored to the catalogue row (an element, a role or a set) each one calls for.
  final List<OcptBreakdownTagRow> breakdownTags;

  /// The `scene_breakdowns` rows of the project: how far the breakdown pass has got, scene by
  /// scene, held by hand rather than deduced.
  final List<OcptSceneBreakdownRow> sceneBreakdowns;

  /// The `row_field_versions` stamps of the rows this payload carries.
  ///
  /// A restore rewinds the data, so it has to rewind the per-column stamps a merge resolves
  /// conflicts with along with it: left at their working-copy values, they would let the next merge
  /// treat the restored columns as older than the very edits the restore was meant to supersede.
  final List<OcptRowFieldVersionRow> rowFieldVersions;

  /// The page setup the project was typeset with when this version was captured.
  ///
  /// This pairs two values of different natures on purpose: the page format is project data
  /// (`project_info.pageFormat`), while the margins are an app-wide preference
  /// (`OcptPropertiesManager.pageMargins`). Carrying both is what keeps the page count shown on a
  /// version's card true — the layout it was counted against travels with it. A *preview* only ever
  /// renders with this setup; only a restore writes the margins back, and only once its database
  /// transaction has committed.
  final OcptPageSetup pageSetup;

  /// The `project_info.settingsJson` of the project, or null if it had none.
  final String? settingsJson;

  /// The `project_info.currencyCode` of the project, or null when this payload predates
  /// currencies (captured in payload format 3 or earlier).
  ///
  /// Unlike every other field of this class, a null here is not "this project had none" — the
  /// column itself is never null — it is "this version doesn't know". That distinction is what
  /// `OcptProjectVersionsService.restoreVersion` reads it for: a restore **leaves the project's
  /// currency untouched** when this is null, rather than overwriting it with a guess, which is the
  /// fail-safe direction (the opposite choice the resources tables make, since their absence is a
  /// truthful "there were none").
  final String? currencyCode;

  /// Class constructor
  const OcptProjectVersionPayload({
    required this.screenplays,
    required this.scenes,
    required this.shots,
    required this.shotCharacters,
    required this.shotCoverages,
    required this.people,
    required this.personPositions,
    required this.personSkills,
    required this.personUnavailabilities,
    required this.roles,
    required this.locations,
    required this.locationAvailabilities,
    required this.sets,
    required this.sceneSets,
    required this.elements,
    required this.sceneElements,
    required this.assets,
    required this.breakdownTags,
    required this.sceneBreakdowns,
    required this.rowFieldVersions,
    required this.pageSetup,
    required this.settingsJson,
    required this.currencyCode,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectVersionPayload(screenplays: ${screenplays.length}, scenes: ${scenes.length}, "
      "shots: ${shots.length}, shotCharacters: ${shotCharacters.length}, "
      "shotCoverages: ${shotCoverages.length}, people: ${people.length}, "
      "personPositions: ${personPositions.length}, personSkills: ${personSkills.length}, "
      "personUnavailabilities: ${personUnavailabilities.length}, roles: ${roles.length}, "
      "locations: ${locations.length}, sets: ${sets.length}, sceneSets: ${sceneSets.length}, "
      "elements: ${elements.length}, sceneElements: ${sceneElements.length}, "
      "assets: ${assets.length}, breakdownTags: ${breakdownTags.length}, "
      "sceneBreakdowns: ${sceneBreakdowns.length}, rowFieldVersions: ${rowFieldVersions.length}, "
      "pageSetup: $pageSetup, currencyCode: $currencyCode)";

  /// Object properties
  @override
  List<Object?> get props => [
    screenplays,
    scenes,
    shots,
    shotCharacters,
    shotCoverages,
    people,
    personPositions,
    personSkills,
    personUnavailabilities,
    roles,
    locations,
    locationAvailabilities,
    sets,
    sceneSets,
    elements,
    sceneElements,
    assets,
    breakdownTags,
    sceneBreakdowns,
    rowFieldVersions,
    pageSetup,
    settingsJson,
    currencyCode,
  ];
}
