// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';

/// One match of the find/replace query in the styled editor's document: in the text of a block,
/// or in the text of a note held by a block.
///
/// A match in a note is ordered where the marker of the note stands in its block, and in the order
/// of the text of the note among the others of that note.
final class OcptStyledSearchMatch {
  /// The identifier of the block holding the match, or the note it is in.
  final String nodeId;

  /// The identifier of the note the match is in, or null for a match in the text of the block.
  final String? noteId;

  /// The match: a range of the text of the block, or of the text of the note when [noteId] is not
  /// null.
  final OcptTextMatch match;

  /// The offset in the text of the block the match is ordered at: where it starts, or where the
  /// marker of its note stands.
  final int anchor;

  /// Tell whether the match is in the text of a note.
  bool get isInNote => noteId != null;

  /// Get the offset the match is ordered at among those sharing its [anchor]: its place in the
  /// text of its note, or before any of them for a match in the text of the block.
  int get orderInAnchor => isInNote ? match.start : -1;

  /// Class constructor.
  const OcptStyledSearchMatch({
    required this.nodeId,
    required this.match,
    required this.anchor,
    this.noteId,
  });

  /// Tell whether the match comes at or after the one at [anchor] and [orderInAnchor] of the same
  /// block.
  bool isAtOrAfter({required int anchor, required int orderInAnchor}) =>
      this.anchor != anchor ? this.anchor > anchor : this.orderInAnchor >= orderInAnchor;
}
