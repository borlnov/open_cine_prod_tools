// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// A screenplay scene as another production mode refers to it: enough to name it in a picker and
/// to match its heading, never enough to render it.
///
/// The resources mode reads these to say which scene is shot in which set (`scene_sets`), so it
/// carries the three things that answer for a scene outside the screenplay — the stable id the link
/// stores, the number the user recognises it by, and the heading `OcptSceneSetSuggestion` matches
/// against a set's name. It deliberately holds neither `charStart`/`charEnd` (only the coverage
/// editor slices scene text, and it has `OcptSceneShotSequence` for that) nor the shots the shot
/// list groups under a scene.
class OcptSceneRef extends Equatable {
  /// The stable, unique id of this scene (a UUID).
  /// {@macro open_cine_prod_tools.OcptSceneIndexService.stability}
  final String id;

  /// The 0-based position of this scene among the screenplay's scenes, in source order.
  final int position;

  /// The normalized scene heading text (e.g. `INT. CUISINE - NUIT`).
  final String heading;

  /// The explicit scene number written in the source (e.g. `4A`), or null if it has none.
  final String? sceneNumber;

  /// Class constructor
  const OcptSceneRef({
    required this.id,
    required this.position,
    required this.heading,
    required this.sceneNumber,
  });

  /// Builds an [OcptSceneRef] from its stored [row].
  factory OcptSceneRef.fromRow(OcptSceneRow row) => OcptSceneRef(
    id: row.id,
    position: row.position,
    heading: row.heading,
    sceneNumber: row.sceneNumber,
  );

  /// The number this scene is shown by: its own [sceneNumber] when it has one, otherwise its
  /// 1-based index among the screenplay's scenes — exactly what the styled screenplay editor
  /// displays for a heading with no explicit number, and what `OcptSceneShotSequence` derives its
  /// own `displaySceneNumber` as.
  String get displayNumber => sceneNumber ?? "${position + 1}";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptSceneRef(id: $id, heading: $heading)";

  /// Object properties
  @override
  List<Object?> get props => [id, position, heading, sceneNumber];
}
