// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_display_number.dart';

/// A screenplay scene as the breakdown mode sees it: its own identity, how far the pass has got on
/// it, and the tags read from it.
///
/// This exists beside `OcptSceneRef` rather than reusing it because the two answer different
/// questions. `OcptSceneRef` deliberately carries neither [charStart] nor [charEnd] — its own doc
/// comment says only the coverage editor slices scene text, and until now nothing else did — but
/// the breakdown mode's script view is exactly that: a second reader of the screenplay that has to
/// slice each scene's own text out of the whole document, the way `OcptShotCoverageLayout` already
/// does for the coverage editor. `OcptSceneShotSequence` carries the same two offsets for the same
/// reason, and is itself not reused here because it also carries a sequence's shots, which have
/// nothing to do with a breakdown pass.
class OcptBreakdownScene extends Equatable {
  /// The stable, unique id of this scene (a UUID).
  final String id;

  /// The 0-based position of this scene among the screenplay's scenes, in source order.
  final int position;

  /// The normalized scene heading text (e.g. `INT. KITCHEN - DAY`).
  final String heading;

  /// The explicit scene number written in the source (e.g. `4A`), or null if it has none.
  final String? sceneNumber;

  /// The character offset, in the screenplay's Fountain text, at which this scene starts.
  ///
  /// [OcptBreakdownTag.startOffset]/[OcptBreakdownTag.endOffset] of every tag in [tags] are
  /// relative to this offset.
  final int charStart;

  /// The character offset, in the screenplay's Fountain text, one past the last character of this
  /// scene.
  final int charEnd;

  /// How far the breakdown pass has got on this scene, held by hand. [OcptBreakdownSceneStatus.toDo]
  /// for a scene with no `scene_breakdowns` row of its own — the service creates one on the first
  /// write, never eagerly.
  final OcptBreakdownSceneStatus status;

  /// This scene's breakdown notes, free text. Empty for a scene with no `scene_breakdowns` row.
  final String notes;

  /// This scene's live tags, ordered by [OcptBreakdownTag.startOffset] — the order the tagged
  /// passages are read in.
  final List<OcptBreakdownTag> tags;

  /// This scene's episode number, or null when the project holds a single episode — the prefix
  /// [displayNumber] reads, passed in rather than looked up: this model has no database access of
  /// its own, and the caller (a bloc) is the one that already knows the project's episode count.
  final int? episodeNumber;

  /// Class constructor
  const OcptBreakdownScene({
    required this.id,
    required this.position,
    required this.heading,
    required this.sceneNumber,
    required this.charStart,
    required this.charEnd,
    required this.status,
    required this.notes,
    required this.tags,
    required this.episodeNumber,
  });

  /// Builds an [OcptBreakdownScene] from its stored [sceneRow] and the live [breakdownRow] of it, if
  /// any — null reading as [OcptBreakdownSceneStatus.toDo] and empty notes, per this class's own doc
  /// comment. [tags] defaults to empty: `OcptBreakdownService.loadScenes` leaves it for
  /// `OcptBreakdownSnapshot.build` to fill in, the way it joins every other read. [episodeNumber] has
  /// no such default — see the field's own doc comment for why it cannot be derived here.
  factory OcptBreakdownScene.fromRows({
    required OcptSceneRow sceneRow,
    required int? episodeNumber,
    OcptSceneBreakdownRow? breakdownRow,
    List<OcptBreakdownTag> tags = const [],
  }) => OcptBreakdownScene(
    id: sceneRow.id,
    position: sceneRow.position,
    heading: sceneRow.heading,
    sceneNumber: sceneRow.sceneNumber,
    charStart: sceneRow.charStart,
    charEnd: sceneRow.charEnd,
    status: breakdownRow?.status ?? OcptBreakdownSceneStatus.toDo,
    notes: breakdownRow?.notes ?? "",
    tags: tags,
    episodeNumber: episodeNumber,
  );

  /// The number this scene is shown by: its own [sceneNumber] when it has one, otherwise its 1-based
  /// index among the screenplay's scenes — exactly what `OcptSceneRef.displayNumber` and
  /// `OcptSceneShotSequence.displaySceneNumber` derive — prefixed with [episodeNumber] once the
  /// project holds more than one.
  String get displayNumber => ocptSceneDisplayNumberOf(
    sceneNumber: sceneNumber,
    position: position,
    episodeNumber: episodeNumber,
  );

  /// This scene with [tags] replacing its own — how `OcptBreakdownSnapshot.build` attaches each live
  /// tag to the scene it belongs to, once `OcptBreakdownService.loadScenes` has loaded the scenes
  /// with none.
  OcptBreakdownScene copyWith({required List<OcptBreakdownTag> tags}) => OcptBreakdownScene(
    id: id,
    position: position,
    heading: heading,
    sceneNumber: sceneNumber,
    charStart: charStart,
    charEnd: charEnd,
    status: status,
    notes: notes,
    tags: tags,
    episodeNumber: episodeNumber,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBreakdownScene(id: $id, heading: $heading, status: $status, tagCount: ${tags.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    position,
    heading,
    sceneNumber,
    charStart,
    charEnd,
    status,
    notes,
    tags,
    episodeNumber,
  ];
}
