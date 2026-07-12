// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:super_editor/super_editor.dart';

/// Builds and maintains the super_editor `MutableDocument` that backs the styled block editor, on
/// top of the invariant the whole styled editing mode is built around: **one `ParagraphNode` per
/// Fountain source line**, blank lines included, so a line's index in the document is always its
/// 0-based source line number.
///
/// This class only holds pure, side-effect-free helpers (build the document from raw text, join
/// it back, and compute the metadata updates a re-classification pass needs): it never touches a
/// live `Editor`, which keeps it trivial to unit test without pumping a widget tree.
class OcptFountainSuperDocument {
  /// Private constructor: this class only exposes static members.
  const OcptFountainSuperDocument._();

  /// The classifier used to turn a line's text into its [FountainLineType], stored as each
  /// node's `blockType` metadata via [OcptFountainLineAttributions].
  static const _classifier = FountainLineClassifier();

  /// Splits [text] into its source lines, normalizing `\r\n`/`\r` line endings to `\n` first (the
  /// same normalization `FountainParser.parse` applies), so a line's index always matches the
  /// source line number the rest of the editor (bloc, scene panel, jump requests) works with.
  static List<String> splitLines(String text) =>
      text.replaceAll("\r\n", "\n").replaceAll("\r", "\n").split("\n");

  /// Builds the initial list of `ParagraphNode`s for [text], one per source line, each already
  /// carrying its classified `blockType` metadata.
  static List<ParagraphNode> buildNodes(String text) {
    final lines = splitLines(text);
    final types = _classifier.classify(lines);

    return [
      for (var index = 0; index < lines.length; index++)
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(lines[index]),
          metadata: {"blockType": OcptFountainLineAttributions.attributionOf(types[index])},
        ),
    ];
  }

  /// Builds a fresh `MutableDocument` for [text], with one node per source line (see
  /// [buildNodes]).
  static MutableDocument buildDocument(String text) => MutableDocument(nodes: buildNodes(text));

  /// Rejoins [document]'s nodes into the flat Fountain source text they represent: the inverse of
  /// [buildDocument], so the styled editor can feed the result back into the existing
  /// `OcptEditorBloc` text-changed pipeline (parse, dirty flag, autosave), shared with raw mode.
  ///
  /// Every node in a styled-mode document is a `TextNode` (only `ParagraphNode`s are ever
  /// inserted, and super_editor only ever splits/merges them into more `ParagraphNode`s), so this
  /// never encounters a node it doesn't know how to serialize back to plain text.
  static String joinText(Document document) =>
      document.map((node) => (node as TextNode).text.toPlainText()).join("\n");

  /// Computes the `ChangeParagraphBlockTypeRequest`s needed to bring every node's `blockType`
  /// metadata back in sync with a fresh classification of [document]'s current lines.
  ///
  /// Only nodes whose classified [FountainLineType] actually changed produce a request: this is
  /// what keeps a reclassification pass after every edit from touching (and so, from the layout's
  /// perspective, recreating) every node in the document, which would otherwise churn the layout
  /// and risk disturbing the caret on every keystroke.
  static List<EditRequest> reclassifyRequests(Document document) {
    final nodes = document.map((node) => node as TextNode).toList(growable: false);
    final lines = [for (final node in nodes) node.text.toPlainText()];
    final types = _classifier.classify(lines);

    final requests = <EditRequest>[];
    for (var index = 0; index < nodes.length; index++) {
      final expectedAttribution = OcptFountainLineAttributions.attributionOf(types[index]);
      final currentBlockType = nodes[index].getMetadataValue("blockType");
      if (currentBlockType is NamedAttribution && currentBlockType.name == expectedAttribution.name) {
        continue;
      }

      requests.add(
        ChangeParagraphBlockTypeRequest(nodeId: nodes[index].id, blockType: expectedAttribution),
      );
    }

    return requests;
  }

  /// The 0-based source line number containing character offset [charOffset] of [text], clamped
  /// to a valid line index (the same convention `OcptEditorSceneJumpRequestedEvent` and the raw
  /// editor's own jump handling use).
  static int lineIndexForCharOffset(String text, int charOffset) {
    final clampedOffset = charOffset.clamp(0, text.length);
    return "\n".allMatches(text.substring(0, clampedOffset)).length;
  }
}
