// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

/// [EditRequest] to replace the entire text of the `ParagraphNode` identified by [nodeId] with
/// [text], leaving its metadata untouched — used by `OcptWysiwygCodec.uppercaseRequests` to rewrite
/// a node's text in place (its length-preserving 1:1 uppercase conversion keeps the composer's
/// current selection offsets valid without a separate `ChangeSelectionRequest`).
@immutable
class OcptReplaceNodeTextRequest implements EditRequest {
  /// The id of the `ParagraphNode` whose text is being replaced.
  final String nodeId;

  /// The new text for the node.
  final AttributedText text;

  /// Brings an offset of the node's former text to the matching offset of [text], for a
  /// replacement that is not length-preserving: the selection and the composing region ends the
  /// node holds are moved through it. Null for a replacement leaving every offset where it was, the
  /// ends the shorter text leaves past its end then being brought back inside it. It plays no part
  /// in the equality of the request.
  final int Function(int offset)? mapOffset;

  /// Get the object hash code
  @override
  int get hashCode => nodeId.hashCode ^ text.hashCode;

  /// Create an [OcptReplaceNodeTextRequest].
  const OcptReplaceNodeTextRequest({required this.nodeId, required this.text, this.mapOffset});

  /// Compare two objects for equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcptReplaceNodeTextRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          text == other.text;
}
