// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_document_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_title_page.dart';
import 'package:super_editor/super_editor.dart';

/// The `ParagraphNode` metadata key holding the dual-dialogue suffix of a character cue, spelled
/// exactly as the source line wrote it (`^` for `KIM^`, ` ^` for `KIM ^`), or null for a cue with
/// none.
///
/// Only ever set on a [FountainLineType.character] node. `OcptWysiwygCodec.decode` strips the
/// suffix out of the cue's display text into this metadata and `OcptWysiwygCodec.encode` writes the
/// stored suffix back, so the marker never shows up as literal text in the styled editor while a
/// round trip stays byte for byte; a `^` typed live at the end of a cue is absorbed the same way by
/// [OcptWysiwygDualDialogue.requests].
const String ocptDualDialogueMetadataKey = "ocptDualDialogue";

/// A dialogue group of the styled editor's document, as the ids of its nodes: the cue first, then
/// its parentheticals and dialogue lines.
typedef OcptDualDialogueGroup = ({
  /// The ids of the group's nodes, in document order, the cue first.
  List<String> nodeIds,

  /// Whether the cue carries the dual-dialogue suffix.
  bool isMarked,

  /// Whether a blank line alone separates the group from the dialogue group right before it.
  bool followsGroup,
});

/// A pair of dialogue groups printed side by side, as the ids of their nodes.
typedef OcptDualDialoguePair = ({List<String> leftNodeIds, List<String> rightNodeIds});

/// What the dual-dialogue toggle shows and does for a caret.
typedef OcptDualDialogueToggle = ({
  /// Whether the caret's speech is part of a pair, or carries a marker with no partner.
  bool isChecked,

  /// The node whose cue the toggle writes to: the one it marks, or the one it unmarks.
  String cueNodeId,
});

/// The dual-dialogue half of `OcptWysiwygCodec`: how the `^` of a character cue leaves the display
/// text for node metadata, which nodes pair up, and what the toggle writes.
///
/// Pure and stateless: it only reads a document and returns what a caller must still execute
/// against a live `Editor`.
final class OcptWysiwygDualDialogue {
  /// The suffix a toggle writes: the usual spelling, a space then the marker.
  static const String uiSuffix = " ^";

  /// Match a dual-dialogue `^` at the end of a cue, with the spaces around it.
  static final RegExp suffixPattern = RegExp(r'\s*\^\s*$');

  /// Private constructor: this class only exposes static members.
  const OcptWysiwygDualDialogue._();

  /// Split a character cue's [text] into the text it shows and its dual-dialogue suffix, or [text]
  /// and null when it has none. A text made of nothing but the marker is left alone.
  static (String, String?) extractSuffix(String text) {
    final match = suffixPattern.firstMatch(text);
    if (match == null || text.substring(0, match.start).trim().isEmpty) {
      return (text, null);
    }
    return (text.substring(0, match.start), match.group(0));
  }

  /// Read [node]'s [ocptDualDialogueMetadataKey] metadata, or null when it carries none.
  static String? suffixOf(ParagraphNode node) {
    final value = node.getMetadataValue(ocptDualDialogueMetadataKey);
    return value is String ? value : null;
  }

  /// Compute the requests keeping the dual-dialogue metadata of [document] in step with its text.
  ///
  /// A cue ending with a `^` typed live has it absorbed: the marker leaves the node's text for
  /// [ocptDualDialogueMetadataKey], like a `#N#` typed at the end of a heading. A node that is no
  /// longer a cue drops the metadata it carries. An inert node is left alone.
  static List<EditRequest> requests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
  }) {
    final requests = <EditRequest>[];
    final inertIds = OcptWysiwygComments.inertNodeIds(document, documentLayout: documentLayout);

    for (final node in document) {
      if (node is! ParagraphNode ||
          node.getMetadataValue(ocptTitlePageKeyMetadataKey) is String ||
          inertIds.contains(node.id)) {
        continue;
      }

      final type = OcptFountainLineAttributions.typeOfAttributionValue(
        node.getMetadataValue("blockType"),
      );
      if (type != FountainLineType.character) {
        if (suffixOf(node) != null) {
          requests.add(
            OcptChangeNodeMetadataRequest(
              nodeId: node.id,
              metadata: {ocptDualDialogueMetadataKey: null},
            ),
          );
        }
        continue;
      }

      final plainText = node.text.toPlainText();
      final (shownText, suffix) = extractSuffix(plainText);
      if (suffix == null) {
        continue;
      }
      requests.add(
        OcptReplaceNodeTextRequest(nodeId: node.id, text: node.text.copyText(0, shownText.length)),
      );
      requests.add(
        OcptChangeNodeMetadataRequest(
          nodeId: node.id,
          metadata: {ocptDualDialogueMetadataKey: suffix},
        ),
      );
    }

    return requests;
  }

  /// Find the dialogue groups of [document]'s body, in order.
  static List<OcptDualDialogueGroup> groupsOf(Document document) =>
      _Lines.of(document).groups.map((group) => group.toGroup()).toList(growable: false);

  /// Find the dual-dialogue pairs of [document]'s body, by the shared pairing rule of
  /// [fountainDualDialogueLinePairs] over the nodes read as source lines.
  static List<OcptDualDialoguePair> pairsOf(Document document) {
    final lines = _Lines.of(document);
    final pairs = fountainDualDialogueLinePairs(lines.types, lines.texts);
    return [
      for (final pair in pairs)
        (leftNodeIds: lines.nodeIdsOf(pair.left), rightNodeIds: lines.nodeIdsOf(pair.right)),
    ];
  }

  /// Read what the toggle shows for a caret in the node [nodeId] of [document], or null when it has
  /// nothing to act on there: no dialogue group, or no other group to pair it with.
  ///
  /// A caret in a pair, left or right, reads as checked and unpairs by removing the right cue's
  /// marker. A caret in a speech carrying a marker with no partner reads as checked and removes
  /// it. Any other speech is paired with the group before it by marking its own cue, or, when that
  /// group already is the right member of a pair, with the group after it by marking that one's.
  static OcptDualDialogueToggle? toggleAt(Document document, String nodeId) {
    final caretNode = document.getNodeById(nodeId);
    if (caretNode is! ParagraphNode ||
        !_Lines._isGroupMember(
          OcptFountainLineAttributions.typeOfAttributionValue(
            caretNode.getMetadataValue("blockType"),
          ),
        )) {
      return null;
    }
    final lines = _Lines.of(document);
    final groups = lines.groups;
    final index = groups.indexWhere((group) => group.nodeIds.contains(nodeId));
    if (index < 0) {
      return null;
    }

    final pairs = fountainDualDialogueLinePairs(lines.types, lines.texts);
    for (final pair in pairs) {
      final rightIds = lines.nodeIdsOf(pair.right);
      if (lines.nodeIdsOf(pair.left).contains(nodeId) || rightIds.contains(nodeId)) {
        return (isChecked: true, cueNodeId: rightIds.first);
      }
    }

    final group = groups[index];
    if (group.isMarked) {
      return (isChecked: true, cueNodeId: group.nodeIds.first);
    }

    final rightIds = {for (final pair in pairs) lines.nodeIdsOf(pair.right).first};
    if (index > 0 && group.followsGroup && !rightIds.contains(groups[index - 1].nodeIds.first)) {
      return (isChecked: false, cueNodeId: group.nodeIds.first);
    }
    if (index + 1 < groups.length && groups[index + 1].followsGroup) {
      return (isChecked: false, cueNodeId: groups[index + 1].nodeIds.first);
    }
    return null;
  }

  /// Get the requests of the toggle for a caret in the node [nodeId] of [document], or null when it
  /// has nothing to act on there (see [toggleAt]): one request, hence one undo step.
  static List<EditRequest>? toggleRequestsAt(Document document, String nodeId) {
    final toggle = toggleAt(document, nodeId);
    if (toggle == null) {
      return null;
    }
    return [suffixRequest(toggle.cueNodeId, toggle.isChecked ? null : uiSuffix)];
  }

  /// Get the request writing [suffix] (or removing the marker when null) on the cue [cueNodeId].
  static EditRequest suffixRequest(String cueNodeId, String? suffix) =>
      OcptChangeNodeMetadataRequest(
        nodeId: cueNodeId,
        metadata: {ocptDualDialogueMetadataKey: suffix},
      );
}

/// A group of the styled editor's document, as node indices into [_Lines.nodes].
final class _Group {
  /// The group's nodes.
  final List<ParagraphNode> nodes;

  /// Whether the cue carries the dual-dialogue suffix.
  final bool isMarked;

  /// Whether a blank line alone separates the group from the group right before it.
  final bool followsGroup;

  /// Get the ids of the group's nodes.
  List<String> get nodeIds => [for (final node in nodes) node.id];

  /// Class constructor.
  const _Group({required this.nodes, required this.isMarked, required this.followsGroup});

  /// Get the group as its public record.
  OcptDualDialogueGroup toGroup() =>
      (nodeIds: nodeIds, isMarked: isMarked, followsGroup: followsGroup);
}

/// The body nodes of a document read as source lines: their types, their texts with the
/// dual-dialogue suffix put back, and the node each line belongs to.
final class _Lines {
  /// The body nodes.
  final List<ParagraphNode> nodes;

  /// The type of each line, a blank for a blank line.
  final List<FountainLineType> types;

  /// The text of each line.
  final List<String> texts;

  /// The index in [nodes] of each line, or -1 for a blank line.
  final List<int> nodeIndexOfLine;

  /// The dialogue groups, in order.
  final List<_Group> groups;

  /// Class constructor.
  const _Lines({
    required this.nodes,
    required this.types,
    required this.texts,
    required this.nodeIndexOfLine,
    required this.groups,
  });

  /// Read the body of [document] as source lines.
  factory _Lines.of(Document document) {
    final nodes = OcptWysiwygComments.bodyNodes(document);
    final inertIds = OcptWysiwygComments.inertNodeIds(document);
    final types = <FountainLineType>[];
    final texts = <String>[];
    final nodeIndexOfLine = <int>[];
    final nodeTypes = <FountainLineType>[];

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final type = inertIds.contains(node.id)
          ? FountainLineType.action
          : OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
      nodeTypes.add(type);
      final continuesGroup =
          index > 0 &&
          (type == FountainLineType.dialogue || type == FountainLineType.parenthetical) &&
          _isGroupMember(nodeTypes[index - 1]);
      final blanks = continuesGroup ? 0 : OcptWysiwygComments.blankLinesBeforeOf(node);
      for (var blank = 0; blank < blanks; blank++) {
        types.add(FountainLineType.blank);
        texts.add("");
        nodeIndexOfLine.add(-1);
      }
      types.add(type);
      final suffix = type == FountainLineType.character
          ? OcptWysiwygDualDialogue.suffixOf(node)
          : null;
      texts.add(OcptWysiwygComments.virtualTextOf(node) + (suffix ?? ""));
      nodeIndexOfLine.add(index);
    }

    return _Lines(
      nodes: nodes,
      types: types,
      texts: texts,
      nodeIndexOfLine: nodeIndexOfLine,
      groups: _groupsOf(nodes, nodeTypes),
    );
  }

  /// Get the ids of the nodes of the lines in [range].
  List<String> nodeIdsOf(FountainLineRange range) => [
    for (var line = range.start; line < range.end; line++)
      if (nodeIndexOfLine[line] >= 0) nodes[nodeIndexOfLine[line]].id,
  ];

  /// Find the dialogue groups among [nodes], whose types are [nodeTypes].
  static List<_Group> _groupsOf(List<ParagraphNode> nodes, List<FountainLineType> nodeTypes) {
    final groups = <_Group>[];
    var previousEnd = -1;
    var index = 0;
    while (index < nodes.length) {
      if (nodeTypes[index] != FountainLineType.character) {
        index++;
        continue;
      }
      var end = index + 1;
      while (end < nodes.length &&
          (nodeTypes[end] == FountainLineType.dialogue ||
              nodeTypes[end] == FountainLineType.parenthetical) &&
          OcptWysiwygComments.blankLinesBeforeOf(nodes[end]) == 0) {
        end++;
      }
      groups.add(
        _Group(
          nodes: nodes.sublist(index, end),
          isMarked: OcptWysiwygDualDialogue.suffixOf(nodes[index]) != null,
          followsGroup:
              previousEnd == index && OcptWysiwygComments.blankLinesBeforeOf(nodes[index]) > 0,
        ),
      );
      previousEnd = end;
      index = end;
    }
    return groups;
  }

  /// Tell whether [type] keeps a dialogue group open.
  static bool _isGroupMember(FountainLineType type) =>
      type == FountainLineType.character ||
      type == FountainLineType.parenthetical ||
      type == FountainLineType.dialogue;
}
