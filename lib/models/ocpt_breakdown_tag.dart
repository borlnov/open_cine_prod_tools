// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';

/// A passage of the screenplay tagged during the breakdown pass, as another part of the mode reads
/// it: the scene it is in, the passage itself, and the one catalogue row it points at.
///
/// `breakdown_tags` stores that last part as three nullable foreign keys plus a discriminator
/// (`elementId`/`roleId`/`setId`/`targetKind` — see `OcptBreakdownTagsTable`'s own doc comment for
/// why), because the schema enforces referential integrity per target table. Nothing above the
/// database ever reasons about three columns, though: it reasons about *the* target this tag
/// points at, so [OcptBreakdownTag.fromRow] collapses the three into the single [targetId] a view
/// actually needs.
///
/// A row whose [OcptBreakdownTagRow.targetKind] names a column that is, somehow, null is a database
/// inconsistency — the write path (`OcptBreakdownService.createTag`) always fills exactly the one
/// column its `targetKind` names — so [OcptBreakdownTag.fromRow] throws a [StateError] naming the
/// tag rather than silently inventing an empty id that would go on to resolve against nothing.
class OcptBreakdownTag extends Equatable {
  /// The stable, unique id of this tag (a UUID).
  final String id;

  /// The scene the tagged passage is in. [startOffset]/[endOffset] are relative to this scene's own
  /// `charStart`.
  final String sceneId;

  /// What kind of catalogue row [targetId] names.
  final OcptBreakdownTargetKind targetKind;

  /// The id of the element, role or set — according to [targetKind] — this tag points at.
  final String targetId;

  /// The character offset, relative to the scene's `charStart`, at which the tagged passage starts.
  final int startOffset;

  /// The character offset, relative to the scene's `charStart`, one past the last character of the
  /// tagged passage.
  final int endOffset;

  /// The tagged passage, verbatim, as it read when this tag was last written or re-anchored.
  final String taggedText;

  /// Whether the passage at [startOffset]/[endOffset] no longer matches [taggedText] and could not
  /// be re-anchored by searching the scene for it.
  final bool needsCheck;

  /// Class constructor
  const OcptBreakdownTag({
    required this.id,
    required this.sceneId,
    required this.targetKind,
    required this.targetId,
    required this.startOffset,
    required this.endOffset,
    required this.taggedText,
    required this.needsCheck,
  });

  /// Builds an [OcptBreakdownTag] from its stored [row], resolving [targetId] out of whichever of
  /// [OcptBreakdownTagRow.elementId]/[OcptBreakdownTagRow.roleId]/[OcptBreakdownTagRow.setId]
  /// [OcptBreakdownTagRow.targetKind] names.
  ///
  /// Throws a [StateError] naming [row]'s id when that column is null — see this class's own doc
  /// comment for why that is a database inconsistency rather than a case to handle silently.
  factory OcptBreakdownTag.fromRow(OcptBreakdownTagRow row) {
    final targetId = switch (row.targetKind) {
      OcptBreakdownTargetKind.element => row.elementId,
      OcptBreakdownTargetKind.role => row.roleId,
      OcptBreakdownTargetKind.set => row.setId,
    };
    if (targetId == null) {
      throw StateError(
        "Breakdown tag ${row.id} names targetKind ${row.targetKind.name} but its matching "
        "column is null",
      );
    }

    return OcptBreakdownTag(
      id: row.id,
      sceneId: row.sceneId,
      targetKind: row.targetKind,
      targetId: targetId,
      startOffset: row.startOffset,
      endOffset: row.endOffset,
      taggedText: row.taggedText,
      needsCheck: row.needsCheck,
    );
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBreakdownTag(id: $id, sceneId: $sceneId, targetKind: $targetKind, targetId: $targetId)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    sceneId,
    targetKind,
    targetId,
    startOffset,
    endOffset,
    taggedText,
    needsCheck,
  ];
}
