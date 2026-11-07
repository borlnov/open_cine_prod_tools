// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// The result of [OcptWysiwygCodec.decode]: everything a caller needs to display a freshly decoded
/// document and later serialize it back to Fountain text.
class OcptWysiwygDecodeResult {
  /// The freshly built document: one `ParagraphNode` per non-blank source line, preceded by
  /// [titlePageNodeCount] title-page field nodes when [OcptWysiwygCodec.decodeWithTitlePage] built
  /// this result (always 0 for plain [OcptWysiwygCodec.decode]).
  final MutableDocument document;

  /// The node-index ↔ source-line mapping for the text [document] was decoded from, scoped to the
  /// **body** text only: a node index into [mapping] is [document]'s own node index minus
  /// [titlePageNodeCount], and a source line/char offset is [document]'s own source text minus its
  /// leading [titlePagePrefixLength] characters (see those fields' own doc comments).
  final OcptWysiwygLineMapping mapping;

  /// The number of blank source lines after the last non-blank line: they have nowhere to attach
  /// as [ocptBlankLinesBeforeMetadataKey] metadata on a following node, so a caller that wants
  /// byte-stable round trips must pass this straight back into [OcptWysiwygCodec.encode].
  final int trailingBlankLines;

  /// The number of leading nodes of [document] that are title-page field nodes (see
  /// [OcptWysiwygCodec.isTitlePageNode]), always 0 for a plain [OcptWysiwygCodec.decode] result. A
  /// caller
  /// translating one of [document]'s own node indices into a [mapping] node index must subtract
  /// this first.
  final int titlePageNodeCount;

  /// The number of leading characters of the full source text
  /// [OcptWysiwygCodec.decodeWithTitlePage] was given that the title page (and the blank line
  /// separating it from the body) consumed, always 0 for a plain [OcptWysiwygCodec.decode] result.
  /// A caller translating a character offset of the full source text into a [mapping] char offset
  /// must subtract this first.
  final int titlePagePrefixLength;

  /// Create an [OcptWysiwygDecodeResult].
  const OcptWysiwygDecodeResult({
    required this.document,
    required this.mapping,
    required this.trailingBlankLines,
    this.titlePageNodeCount = 0,
    this.titlePagePrefixLength = 0,
  });
}
