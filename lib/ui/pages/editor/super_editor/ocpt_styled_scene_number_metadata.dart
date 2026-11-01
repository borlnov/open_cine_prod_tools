// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Read the scene numbers a styled editor's gutter shows off its document's node metadata.
final class OcptStyledSceneNumberMetadata {
  /// Private constructor: this class only exposes static members.
  const OcptStyledSceneNumberMetadata._();

  /// Get the scene number to show next to every scene-heading node currently in [document], keyed
  /// by node id, read straight off each node's [ocptSceneNumberMetadataKey] metadata.
  ///
  /// By the time this is called (every build), that metadata is already correct: it was set by
  /// [OcptWysiwygCodec.decode] for an explicit tag, or normalized by the styled editor's own `sceneNumberNormalizationRequests` pass right after every rebuild or
  /// edit, so this is a plain read, not a fresh computation.
  static Map<String, String> of(Document document) {
    final numbers = <String, String>{};
    for (final node in document) {
      if (node is! ParagraphNode) {
        continue;
      }
      final type = OcptFountainLineAttributions.typeOfAttributionValue(
        node.getMetadataValue("blockType"),
      );
      if (type != FountainLineType.sceneHeading) {
        continue;
      }
      final value = node.getMetadataValue(ocptSceneNumberMetadataKey);
      if (value is String) {
        numbers[node.id] = value;
      }
    }
    return numbers;
  }
}
