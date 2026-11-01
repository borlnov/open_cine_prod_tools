// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

/// [EditRequest] to merge [metadata] into the app-specific metadata (`ocptBlankLinesBefore`,
/// `ocptTypeLocked`, `ocptHadForcingMarker`, `ocptSceneNumber`) of the `ParagraphNode` identified
/// by [nodeId], without touching its `blockType` (already covered by super_editor's own
/// `ChangeParagraphBlockTypeRequest`).
///
/// Modeled directly on super_editor's own `ChangeParagraphBlockTypeRequest`/
/// `ChangeParagraphBlockTypeCommand` pair
/// (`package:super_editor/src/default_editor/paragraph.dart`): this class is deliberately generic
/// (it doesn't know the app's specific metadata key names) so it can carry any of them, alone or
/// together, in a single request.
@immutable
class OcptChangeNodeMetadataRequest implements EditRequest {
  /// The id of the `ParagraphNode` whose metadata is being updated.
  final String nodeId;

  /// The metadata entries to merge into the node's existing metadata (added or overwritten; every
  /// other existing entry, including `blockType`, is left untouched).
  final Map<String, dynamic> metadata;

  /// {@template open_cine_prod_tools.OcptChangeNodeMetadataRequest.isHistorical}
  /// Whether this change may become (part of) an undo step.
  ///
  /// True for every change a gesture of the writer's caused, directly or through the passes the
  /// editor derives from it. False only for a change made *before the writer has touched
  /// anything* — the scene-number normalization that runs the moment a screenplay is decoded (see
  /// `sceneNumberNormalizationRequests`) — which would otherwise be the first thing Ctrl+Z popped
  /// on a freshly opened screenplay, un-correcting a numbering the writer never asked to change.
  /// `Editor` offers no way to clear history and its `isHistoryEnabled` is final, so the
  /// command's own `historyBehavior` is the only lever there is.
  /// {@endtemplate}
  final bool isHistorical;

  /// Object hash code
  @override
  int get hashCode =>
      nodeId.hashCode ^
      isHistorical.hashCode ^
      Object.hashAllUnordered(metadata.entries.map((e) => Object.hash(e.key, e.value)));

  /// Creates an [OcptChangeNodeMetadataRequest].
  const OcptChangeNodeMetadataRequest({
    required this.nodeId,
    required this.metadata,
    this.isHistorical = true,
  });

  /// Object equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcptChangeNodeMetadataRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          isHistorical == other.isHistorical &&
          _mapsEqual(metadata, other.metadata);

  /// Whether [a] and [b] hold the same keys mapped to the same values (order-independent).
  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
