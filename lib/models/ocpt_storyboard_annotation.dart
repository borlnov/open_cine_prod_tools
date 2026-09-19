// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// One mark drawn over a storyboard panel's frame, as the board reads it back off its stored
/// `storyboard_annotations` row.
///
/// [x1]/[y1]/[x2]/[y2] stay normalised 0..1 to the frame, exactly as the table stores them — see
/// `OcptStoryboardAnnotationsTable`'s own doc comment for why: a replaced image of another size
/// keeps every mark where it was. [x2]/[y2] are meaningless (and left at the row's stored 0) when
/// [kind] is [OcptStoryboardAnnotationKind.label].
class OcptStoryboardAnnotation extends Equatable {
  /// The stable, unique id of this annotation (a UUID).
  final String id;

  /// The panel this mark is drawn on.
  final String panelId;

  /// What kind of mark this is.
  final OcptStoryboardAnnotationKind kind;

  /// The draw order among the panel's other marks.
  final String sortKey;

  /// The first end's X coordinate, normalised 0..1 to the frame — a label's anchor point, or an
  /// arrow's tail.
  final double x1;

  /// The first end's Y coordinate, normalised 0..1 to the frame.
  final double y1;

  /// The second end's X coordinate, normalised 0..1 to the frame — an arrow's head.
  final double x2;

  /// The second end's Y coordinate, normalised 0..1 to the frame.
  final double y2;

  /// The label's text, or an arrow's optional caption.
  final String text;

  /// Class constructor
  const OcptStoryboardAnnotation({
    required this.id,
    required this.panelId,
    required this.kind,
    required this.sortKey,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.text,
  });

  /// Builds an [OcptStoryboardAnnotation] from its stored [row].
  factory OcptStoryboardAnnotation.fromRow(OcptStoryboardAnnotationRow row) =>
      OcptStoryboardAnnotation(
        id: row.id,
        panelId: row.panelId,
        kind: row.kind,
        sortKey: row.sortKey,
        x1: row.x1,
        y1: row.y1,
        x2: row.x2,
        y2: row.y2,
        text: row.labelText,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptStoryboardAnnotation(id: $id, panelId: $panelId, kind: $kind, text: $text)";

  /// Object properties
  @override
  List<Object?> get props => [id, panelId, kind, sortKey, x1, y1, x2, y2, text];
}
