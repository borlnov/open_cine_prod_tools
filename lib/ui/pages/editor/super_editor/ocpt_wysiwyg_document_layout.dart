// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comment_layout.dart';
import 'package:super_editor/super_editor.dart';

/// The body nodes of a document laid out as source lines, with where the commented spans fall in
/// them: what every derived pass of `OcptWysiwygCodec` reads, computed once for a settle and
/// handed to each pass, instead of each pass laying the whole document out again.
///
/// It describes the document as it was when it was built: a pass that changed a node's text makes
/// it stale.
final class OcptWysiwygDocumentLayout {
  /// The body paragraphs, the title-page fields left out.
  final List<ParagraphNode> nodes;

  /// Where the commented spans fall in the lines of [nodes].
  final OcptWysiwygCommentLayout comments;

  /// The index, in the lines of [comments], of the line of each node.
  final List<int> lineIndexOfNode;

  /// The source text of each node, the one the commented spans were looked for in.
  final List<String> sourceTexts;

  /// Class constructor.
  const OcptWysiwygDocumentLayout({
    required this.nodes,
    required this.comments,
    required this.lineIndexOfNode,
    required this.sourceTexts,
  });
}
