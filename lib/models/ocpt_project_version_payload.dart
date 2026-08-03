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

  /// Class constructor
  const OcptProjectVersionPayload({
    required this.screenplays,
    required this.scenes,
    required this.shots,
    required this.shotCharacters,
    required this.shotCoverages,
    required this.rowFieldVersions,
    required this.pageSetup,
    required this.settingsJson,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectVersionPayload(screenplays: ${screenplays.length}, scenes: ${scenes.length}, "
      "shots: ${shots.length}, shotCharacters: ${shotCharacters.length}, "
      "shotCoverages: ${shotCoverages.length}, rowFieldVersions: ${rowFieldVersions.length}, "
      "pageSetup: $pageSetup)";

  /// Object properties
  @override
  List<Object?> get props => [
    screenplays,
    scenes,
    shots,
    shotCharacters,
    shotCoverages,
    rowFieldVersions,
    pageSetup,
    settingsJson,
  ];
}
