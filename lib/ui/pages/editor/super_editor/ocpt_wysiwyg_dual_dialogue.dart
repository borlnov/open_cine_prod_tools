// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_document_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_note_offsets.dart';
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

/// What a document holds of dual dialogue: its pairs, its cues carrying a hidden `^` with no
/// partner on their left, and a key that changes whenever either does.
typedef OcptDualDialogueAnalysis = ({
  /// The pairs set side by side, in document order.
  List<OcptDualDialoguePair> pairs,

  /// The ids of the cue nodes carrying a hidden `^` that is not the mark of a right member.
  Set<String> orphanCueIds,

  /// A key that changes whenever [pairs] or [orphanCueIds] do.
  String key,
});

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

  /// The analyses already computed, by document, dropped as soon as their document changes.
  static final Expando<_Analysis> _analyses = Expando<_Analysis>("dualDialogueAnalysis");

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
  /// longer a cue gets the suffix it carries written back at the end of its text, so no character
  /// of the source is lost. An inert node is left alone, and so is a node in [composingNodeIds],
  /// whose text an input method is still composing: it is dealt with at the next settle.
  static List<EditRequest> requests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
    Set<String> composingNodeIds = const {},
  }) {
    final requests = <EditRequest>[];
    final inertIds = OcptWysiwygComments.inertNodeIds(document, documentLayout: documentLayout);

    for (final node in document) {
      if (node is! ParagraphNode ||
          node.getMetadataValue(ocptTitlePageKeyMetadataKey) is String ||
          inertIds.contains(node.id) ||
          composingNodeIds.contains(node.id)) {
        continue;
      }

      final type = OcptFountainLineAttributions.typeOfAttributionValue(
        node.getMetadataValue("blockType"),
      );
      if (type != FountainLineType.character) {
        final storedSuffix = suffixOf(node);
        if (storedSuffix != null) {
          // The node stops being a cue for now: the marker goes back into its text, where raw mode
          // would hold it, and is absorbed again if the node reads as a cue once more.
          requests.add(
            OcptReplaceNodeTextRequest(
              nodeId: node.id,
              text: node.text.copyAndAppend(AttributedText(storedSuffix)),
            ),
          );
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
  static List<OcptDualDialoguePair> pairsOf(Document document) => _pairsOf(_Lines.of(document));

  /// Get what [document] holds of dual dialogue, computed once per change of the document: the
  /// bracket builder and the owner deciding when to build a fresh one both read it, and a document
  /// carrying no marker at all costs one cheap pass over its nodes.
  static OcptDualDialogueAnalysis analysisOf(Document document) {
    var entry = _analyses[document];
    if (entry == null) {
      final created = entry = _Analysis();
      _analyses[document] = created;
      document.addListener((_) => created.value = null);
    }
    return entry.value ??= _analyze(document);
  }

  /// Read what the toggle shows for a caret in the node [nodeId] of [document], or null when it has
  /// nothing to act on there: no dialogue group, or no other group to pair it with.
  ///
  /// A caret in a pair, left or right, reads as checked and unpairs by removing the right cue's
  /// marker. A caret in a speech carrying a marker with no partner reads as checked and removes
  /// it. Any other speech is paired with the group before it by marking its own cue, or, when that
  /// group already is a member of a pair, with the group after it by marking that one's, unless
  /// that one is the left member of a pair of its own, which marking it would break.
  ///
  /// Only the run of dialogue groups the caret's group belongs to is read, never the whole
  /// document: a pair can only be made of two groups with nothing but blank lines between them.
  static OcptDualDialogueToggle? toggleAt(Document document, String nodeId) {
    final caretNode = document.getNodeById(nodeId);
    if (caretNode is! ParagraphNode) {
      return null;
    }
    final window = _Window.around(document, caretNode);
    if (window == null) {
      return null;
    }
    final lines = _Lines.ofNodes(window, _Window.isInert);
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

    final rightCueIds = {for (final pair in pairs) lines.nodeIdsOf(pair.right).first};
    final leftCueIds = {for (final pair in pairs) lines.nodeIdsOf(pair.left).first};
    if (index > 0 && group.followsGroup && !rightCueIds.contains(groups[index - 1].nodeIds.first)) {
      return (isChecked: false, cueNodeId: group.nodeIds.first);
    }
    if (index + 1 < groups.length &&
        groups[index + 1].followsGroup &&
        !leftCueIds.contains(groups[index + 1].nodeIds.first)) {
      return (isChecked: false, cueNodeId: groups[index + 1].nodeIds.first);
    }
    return null;
  }

  /// Get the requests of the toggle for a caret in the node [nodeId] of [document], or null when it
  /// has nothing to act on there (see [toggleAt]) or nothing to write: one request group, hence at
  /// most one undo step.
  static List<EditRequest>? toggleRequestsAt(Document document, String nodeId) {
    final toggle = toggleAt(document, nodeId);
    if (toggle == null) {
      return null;
    }
    if (!toggle.isChecked) {
      return [suffixRequest(toggle.cueNodeId, uiSuffix)];
    }
    final cue = document.getNodeById(toggle.cueNodeId);
    if (cue is! ParagraphNode) {
      return null;
    }
    if (suffixOf(cue) != null) {
      return [suffixRequest(toggle.cueNodeId, null)];
    }
    // The marker is plain text, followed by a note: removing it keeps everything else in place.
    final offsets = OcptWysiwygNoteOffsets.of(cue.text);
    final span = _markerSpanIn(offsets.expand(cue.text.toPlainText()));
    if (span == null) {
      return null;
    }
    final (start, end) = offsets.nodeRangeOf(span.$1, span.$2);
    return [
      OcptReplaceNodeTextRequest(
        nodeId: cue.id,
        text: cue.text.copyText(0, start).copyAndAppend(cue.text.copyText(end)),
      ),
    ];
  }

  /// Get the request writing [suffix] (or removing the marker when null) on the cue [cueNodeId].
  static EditRequest suffixRequest(String cueNodeId, String? suffix) =>
      OcptChangeNodeMetadataRequest(
        nodeId: cueNodeId,
        metadata: {ocptDualDialogueMetadataKey: suffix},
      );

  /// Compute the pairs and the orphan cues of [document].
  static OcptDualDialogueAnalysis _analyze(Document document) {
    if (!document.whereType<ParagraphNode>().any(_mayCarryMarker)) {
      return (pairs: const [], orphanCueIds: const {}, key: "");
    }
    final lines = _Lines.of(document);
    final pairs = _pairsOf(lines);
    final rightCueIds = {for (final pair in pairs) pair.rightNodeIds.first};
    final orphanCueIds = {
      for (final group in lines.groups)
        if (group.hasHiddenSuffix && !rightCueIds.contains(group.nodes.first.id))
          group.nodes.first.id,
    };
    final key =
        "${[
          for (final pair in pairs) [...pair.leftNodeIds, ...pair.rightNodeIds],
        ]}|${orphanCueIds.toList()}";
    return (pairs: pairs, orphanCueIds: orphanCueIds, key: key);
  }

  /// Tell whether [node] may hold a dual-dialogue marker, hidden or written out.
  static bool _mayCarryMarker(ParagraphNode node) =>
      suffixOf(node) != null || node.text.toPlainText().contains("^");

  /// Find the pairs among [lines].
  static List<OcptDualDialoguePair> _pairsOf(_Lines lines) => [
    for (final pair in fountainDualDialogueLinePairs(lines.types, lines.texts))
      (leftNodeIds: lines.nodeIdsOf(pair.left), rightNodeIds: lines.nodeIdsOf(pair.right)),
  ];

  /// Find where the marker of a cue written out in [text] sits, with the spaces before it, as a
  /// (start, end) range, or null when [text] ends with none: only whitespace and notes may follow
  /// the `^`.
  static (int, int)? _markerSpanIn(String text) {
    final notes = FountainCommentSpans.notes(text);
    var end = text.length;
    while (true) {
      var trimmed = end;
      while (trimmed > 0 && text[trimmed - 1].trim().isEmpty) {
        trimmed--;
      }
      final note = notes.where((span) => span.end == trimmed).firstOrNull;
      if (note == null) {
        end = trimmed;
        break;
      }
      end = note.start;
    }
    if (end == 0 || text[end - 1] != "^") {
      return null;
    }
    var start = end - 1;
    while (start > 0 && text[start - 1].trim().isEmpty) {
      start--;
    }
    return (start, end);
  }
}

/// The analysis of a document, kept until the document next changes.
final class _Analysis {
  /// The analysis, or null when it has to be computed again.
  OcptDualDialogueAnalysis? value;
}

/// The run of dialogue groups around a caret, read without walking the whole document: the nodes
/// from the first group of the run to the end of the last, groups being adjacent when nothing but
/// blank lines separates them.
final class _Window {
  /// Private constructor: this class only exposes static members.
  const _Window._();

  /// Find the nodes of the run of groups [caret] belongs to, or null when it is in none.
  static List<ParagraphNode>? around(Document document, ParagraphNode caret) {
    final caretIndex = document.getNodeIndexById(caret.id);
    final caretCue = _cueIndexOf(document, caretIndex);
    if (caretCue == null) {
      return null;
    }

    return _collect(document, caretCue);
  }

  /// Tell whether [node] is inert, judging by the comment attribution a settle left on its text.
  static bool isInert(ParagraphNode node) {
    final length = node.text.length;
    if (length == 0 ||
        !node.text.hasAttributionAt(0, attribution: ocptFountainCommentAttribution)) {
      return false;
    }
    return node.text.hasAttributionsThroughout(
      attributions: {ocptFountainCommentAttribution},
      range: SpanRange(0, length - 1),
    );
  }

  /// Get the live body paragraph at [index], or null when there is none there.
  static ParagraphNode? _nodeAt(Document document, int index) {
    if (index < 0 || index >= document.nodeCount) {
      return null;
    }
    final node = document.getNodeAt(index);
    return node is ParagraphNode && node.getMetadataValue(ocptTitlePageKeyMetadataKey) is! String
        ? node
        : null;
  }

  /// Get the type of [node] as the pairing reads it: an inert node is no part of a group.
  static FountainLineType _typeOf(ParagraphNode node) => isInert(node)
      ? FountainLineType.action
      : OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));

  /// Tell whether [type] keeps a dialogue group open.
  static bool _isMember(FountainLineType type) => _Lines._isGroupMember(type);

  /// Find the index of the cue of the group holding the node at [index], or null when it is in
  /// none.
  static int? _cueIndexOf(Document document, int index) {
    var cursor = index;
    while (true) {
      final node = _nodeAt(document, cursor);
      if (node == null) {
        return null;
      }
      final type = _typeOf(node);
      if (type == FountainLineType.character) {
        return cursor;
      }
      final before = _nodeAt(document, cursor - 1);
      if ((type != FountainLineType.dialogue && type != FountainLineType.parenthetical) ||
          OcptWysiwygComments.blankLinesBeforeOf(node) != 0 ||
          before == null ||
          !_isMember(_typeOf(before))) {
        return null;
      }
      cursor--;
    }
  }

  /// Get the index right after the last node of the group whose cue is at [cue].
  static int _endOfGroup(Document document, int cue) {
    var end = cue + 1;
    while (true) {
      final node = _nodeAt(document, end);
      if (node == null) {
        return end;
      }
      final type = _typeOf(node);
      if ((type != FountainLineType.dialogue && type != FountainLineType.parenthetical) ||
          OcptWysiwygComments.blankLinesBeforeOf(node) != 0) {
        return end;
      }
      end++;
    }
  }

  /// Get the nodes of the run of groups the group whose cue is at [cue] belongs to.
  static List<ParagraphNode> _collect(Document document, int cue) {
    var first = cue;
    while (true) {
      final cueNode = _nodeAt(document, first)!;
      final before = _nodeAt(document, first - 1);
      final previousCue = OcptWysiwygComments.blankLinesBeforeOf(cueNode) > 0 && before != null
          ? _cueIndexOf(document, first - 1)
          : null;
      if (previousCue == null) {
        break;
      }
      first = previousCue;
    }

    var end = _endOfGroup(document, cue);
    while (true) {
      final next = _nodeAt(document, end);
      if (next == null ||
          _typeOf(next) != FountainLineType.character ||
          OcptWysiwygComments.blankLinesBeforeOf(next) == 0) {
        break;
      }
      end = _endOfGroup(document, end);
    }

    return [for (var index = first; index < end; index++) _nodeAt(document, index)!];
  }
}

/// A group of the styled editor's document.
final class _Group {
  /// The group's nodes.
  final List<ParagraphNode> nodes;

  /// Whether the cue carries the dual-dialogue marker, hidden in its metadata or written out.
  final bool isMarked;

  /// Whether the marker is the hidden suffix of the cue's metadata.
  final bool hasHiddenSuffix;

  /// Whether a blank line alone separates the group from the group right before it.
  final bool followsGroup;

  /// Get the ids of the group's nodes.
  List<String> get nodeIds => [for (final node in nodes) node.id];

  /// Class constructor.
  const _Group({
    required this.nodes,
    required this.isMarked,
    required this.hasHiddenSuffix,
    required this.followsGroup,
  });

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
  factory _Lines.of(Document document) =>
      _Lines.ofNodes(OcptWysiwygComments.bodyNodes(document), _Window.isInert);

  /// Read [nodes], consecutive body nodes, as source lines, [isInert] telling which of them are
  /// left out of the screenplay.
  factory _Lines.ofNodes(List<ParagraphNode> nodes, bool Function(ParagraphNode) isInert) {
    final types = <FountainLineType>[];
    final texts = <String>[];
    final nodeIndexOfLine = <int>[];
    final nodeTypes = <FountainLineType>[];
    final lineOfNode = <int>[];

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final type = isInert(node)
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
      lineOfNode.add(texts.length);
      texts.add(OcptWysiwygComments.virtualTextOf(node) + (suffix ?? ""));
      nodeIndexOfLine.add(index);
    }

    return _Lines(
      nodes: nodes,
      types: types,
      texts: texts,
      nodeIndexOfLine: nodeIndexOfLine,
      groups: _groupsOf(nodes, nodeTypes, texts, lineOfNode),
    );
  }

  /// Get the ids of the nodes of the lines in [range].
  List<String> nodeIdsOf(FountainLineRange range) => [
    for (var line = range.start; line < range.end; line++)
      if (nodeIndexOfLine[line] >= 0) nodes[nodeIndexOfLine[line]].id,
  ];

  /// Find the dialogue groups among [nodes], whose types are [nodeTypes] and whose lines are
  /// [texts], the line of the node at an index being `lineOfNode` of it.
  static List<_Group> _groupsOf(
    List<ParagraphNode> nodes,
    List<FountainLineType> nodeTypes,
    List<String> texts,
    List<int> lineOfNode,
  ) {
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
          isMarked: parseFountainCharacterCue(
            FountainLineClassifier.withoutInlineNotes(texts[lineOfNode[index]]),
          ).isDualDialogue,
          hasHiddenSuffix: OcptWysiwygDualDialogue.suffixOf(nodes[index]) != null,
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
