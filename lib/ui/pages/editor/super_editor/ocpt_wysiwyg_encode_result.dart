// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';

/// The result of [OcptWysiwygCodec.encode]: the serialized Fountain source text, plus a mapping
/// freshly built for that exact text (the inverse of [OcptWysiwygDecodeResult]).
class OcptWysiwygEncodeResult {
  /// Creates an [OcptWysiwygEncodeResult].
  const OcptWysiwygEncodeResult({
    required this.text,
    required this.mapping,
    this.titlePageNodeCount = 0,
    this.titlePagePrefixLength = 0,
  });

  /// The full Fountain source text serialized from the document.
  final String text;

  /// The node-index ↔ source-line mapping for [text], scoped to the **body** text only: see
  /// [OcptWysiwygDecodeResult.mapping]'s own doc comment, which this mirrors exactly.
  final OcptWysiwygLineMapping mapping;

  /// See [OcptWysiwygDecodeResult.titlePageNodeCount]; always 0 for a plain
  /// [OcptWysiwygCodec.encode] result.
  final int titlePageNodeCount;

  /// See [OcptWysiwygDecodeResult.titlePagePrefixLength]; always 0 for a plain
  /// [OcptWysiwygCodec.encode] result.
  final int titlePagePrefixLength;
}
