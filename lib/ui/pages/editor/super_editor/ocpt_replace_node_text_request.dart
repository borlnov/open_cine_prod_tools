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

  /// Get the object hash code
  @override
  int get hashCode => nodeId.hashCode ^ text.hashCode;

  /// Create an [OcptReplaceNodeTextRequest].
  const OcptReplaceNodeTextRequest({required this.nodeId, required this.text});

  /// Compare two objects for equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcptReplaceNodeTextRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          text == other.text;
}
