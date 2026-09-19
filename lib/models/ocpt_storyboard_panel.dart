// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';

/// One imported frame of a shot's storyboard, as `OcptStoryboardService.loadStoryboard` builds it:
/// its stored fields, the image's resolved path (through the `assets` table, ADR 0013) and its
/// live annotations.
///
/// A shot holds **0..N** of these, ordered by [sortKey] — see `OcptStoryboardPanelsTable`'s own
/// doc comment. [imagePath] is null exactly when [imageAssetId] is null (no image imported yet, or
/// one removed without a replacement); a non-null [imageAssetId] whose `assets` row was somehow not
/// found resolves [imagePath] to null too, which the board reads the same way `OcptReferencedImage`
/// reads a path that names no file — a normal state, not an error.
class OcptStoryboardPanel extends Equatable {
  /// The stable, unique id of this panel (a UUID).
  final String id;

  /// The shot this panel belongs to.
  final String shotId;

  /// The order within the shot's other panels.
  final String sortKey;

  /// The panel's frame `assets` row id, or null while no image has been imported yet.
  final String? imageAssetId;

  /// The frame's resolved absolute path, or null. See the class doc comment.
  final String? imagePath;

  /// The free comment shown under the frame.
  final String comment;

  /// This panel's marks, in draw order.
  final List<OcptStoryboardAnnotation> annotations;

  /// Class constructor
  const OcptStoryboardPanel({
    required this.id,
    required this.shotId,
    required this.sortKey,
    required this.imageAssetId,
    required this.imagePath,
    required this.comment,
    required this.annotations,
  });

  /// Builds an [OcptStoryboardPanel] from its stored [row], the resolved [imagePath] of its image
  /// asset (or null), and its live [annotations] (already in draw order).
  factory OcptStoryboardPanel.fromRow({
    required OcptStoryboardPanelRow row,
    required String? imagePath,
    required List<OcptStoryboardAnnotation> annotations,
  }) => OcptStoryboardPanel(
    id: row.id,
    shotId: row.shotId,
    sortKey: row.sortKey,
    imageAssetId: row.imageAssetId,
    imagePath: imagePath,
    comment: row.comment,
    annotations: annotations,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptStoryboardPanel(id: $id, shotId: $shotId, hasImage: ${imagePath != null}, "
      "annotations: ${annotations.length})";

  /// Object properties
  @override
  List<Object?> get props => [id, shotId, sortKey, imageAssetId, imagePath, comment, annotations];
}
