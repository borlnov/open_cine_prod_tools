// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:super_editor/super_editor.dart';

/// The `ParagraphNode` metadata key holding the number of blank source lines that preceded a node
/// (0 inside a dialogue group, since a real blank line there would break the group).
const String ocptBlankLinesBeforeMetadataKey = "ocptBlankLinesBefore";

/// The `ParagraphNode` metadata key holding whether a node's `blockType` was set manually (a
/// future dropdown/Tab choice) rather than by auto-detection; [OcptWysiwygCodec.reclassifyRequests]
/// skips a locked node, and clears the lock once the node's text is emptied.
const String ocptTypeLockedMetadataKey = "ocptTypeLocked";

/// The `ParagraphNode` metadata key holding whether the source line a node was decoded from used
/// an explicit forcing marker, so [OcptWysiwygCodec.encode] can re-emit it even when
/// auto-detection alone would already yield the same type (byte-stable round trips).
const String ocptHadForcingMarkerMetadataKey = "ocptHadForcingMarker";

/// The attribution marking an inline authoring note (`[[text]]`) for dimmed rendering; unlike
/// [boldAttribution]/[italicsAttribution]/[underlineAttribution], a note's delimiters stay part of
/// its node's plain text (see [FountainStyledRun.isNote]), so this attribution is only ever used
/// for styling, never for serialization (a node's text already carries the brackets verbatim).
const NamedAttribution ocptFountainNoteAttribution = NamedAttribution("fountainNote");

/// The result of [OcptWysiwygCodec.decode]: everything a caller needs to display a freshly decoded
/// document and later serialize it back to Fountain text.
class OcptWysiwygDecodeResult {
  /// Creates an [OcptWysiwygDecodeResult].
  const OcptWysiwygDecodeResult({required this.document, required this.mapping, required this.trailingBlankLines});

  /// The freshly built document: one `ParagraphNode` per non-blank source line.
  final MutableDocument document;

  /// The node-index ↔ source-line mapping for the text [document] was decoded from.
  final OcptWysiwygLineMapping mapping;

  /// The number of blank source lines after the last non-blank line: they have nowhere to attach
  /// as [ocptBlankLinesBeforeMetadataKey] metadata on a following node, so a caller that wants
  /// byte-stable round trips must pass this straight back into [OcptWysiwygCodec.encode].
  final int trailingBlankLines;
}

/// The result of [OcptWysiwygCodec.encode]: the serialized Fountain source text, plus a mapping
/// freshly built for that exact text (the inverse of [OcptWysiwygDecodeResult]).
class OcptWysiwygEncodeResult {
  /// Creates an [OcptWysiwygEncodeResult].
  const OcptWysiwygEncodeResult({required this.text, required this.mapping});

  /// The full Fountain source text serialized from the document.
  final String text;

  /// The node-index ↔ source-line mapping for [text].
  final OcptWysiwygLineMapping mapping;
}

/// The node-index ↔ source-line mapping produced by both [OcptWysiwygCodec.decode] and
/// [OcptWysiwygCodec.encode], letting the styled editor report caret lines and resolve scene-panel
/// jump requests without the old model's "node index == line index" invariant, now that blank
/// source lines are folded into node metadata instead of being their own node.
class OcptWysiwygLineMapping {
  /// Builds the mapping for [sourceText], given, in node order, each node's (already resolved, in
  /// the case of [OcptWysiwygCodec.encode]'s dialogue-group override) blank-line-before count, and
  /// the number of blank lines trailing the last node.
  OcptWysiwygLineMapping._build({
    required String sourceText,
    required List<int> blankLinesBeforeByNode,
    required int trailingBlankLines,
  }) : _sourceText = sourceText {
    var line = 0;
    for (var nodeIndex = 0; nodeIndex < blankLinesBeforeByNode.length; nodeIndex++) {
      for (var blank = 0; blank < blankLinesBeforeByNode[nodeIndex]; blank++) {
        _nodeIndexByLine.add(nodeIndex);
        line++;
      }
      _lineByNodeIndex.add(line);
      _nodeIndexByLine.add(nodeIndex);
      line++;
    }

    final lastNodeIndex = blankLinesBeforeByNode.isEmpty ? 0 : blankLinesBeforeByNode.length - 1;
    for (var blank = 0; blank < trailingBlankLines; blank++) {
      _nodeIndexByLine.add(lastNodeIndex);
    }
  }

  /// The text [nodeIndexOfCharOffset] resolves a character offset against.
  final String _sourceText;

  /// The 0-based source line of each node, indexed by node index.
  final List<int> _lineByNodeIndex = [];

  /// The node index owning each 0-based source line (a blank line's entry points at the node
  /// following it), indexed by line number.
  final List<int> _nodeIndexByLine = [];

  /// The 0-based source line the node at [nodeIndex] sits on, accounting for every preceding
  /// node's [ocptBlankLinesBeforeMetadataKey] metadata; [nodeIndex] is clamped to a valid index.
  int lineOfNodeIndex(int nodeIndex) => _lineByNodeIndex[nodeIndex.clamp(0, _lineByNodeIndex.length - 1)];

  /// The 0-based node index owning the source line containing character offset [charOffset] of
  /// this mapping's own source text, clamped to a valid line (out-of-range clamps to the text's
  /// length, i.e. the last line, the same convention the old `lineIndexForCharOffset` used). A
  /// blank line's offset snaps to the node immediately following it (or, if it's a trailing blank
  /// line with no following node, to the last node).
  int nodeIndexOfCharOffset(int charOffset) {
    final clampedOffset = charOffset.clamp(0, _sourceText.length);
    final line = "\n".allMatches(_sourceText.substring(0, clampedOffset)).length;
    return _nodeIndexByLine[line.clamp(0, _nodeIndexByLine.length - 1)];
  }
}

/// Converts between Fountain source text and the super_editor `MutableDocument` backing the
/// styled block editor, on the invariant the whole styled editing mode is built around: **one
/// `ParagraphNode` per non-blank Fountain source line**. Blank source lines carry no node of their
/// own; they are folded into the [ocptBlankLinesBeforeMetadataKey] metadata of the node that
/// follows them (or, for blank lines trailing the very last node, into a
/// [OcptWysiwygDecodeResult.trailingBlankLines]/[encode] `trailingBlankLines` count that lives
/// beside the document rather than inside it).
///
/// A node's text is its **display text**: any forcing prefix the source line used is stripped
/// (preserved instead as [ocptHadForcingMarkerMetadataKey] metadata) and inline emphasis markers
/// (`**`, `*`, `_`) are converted to real `AttributedText` attributions ([boldAttribution],
/// [italicsAttribution], [underlineAttribution]) instead of staying as literal markup characters;
/// an inline authoring note (`[[text]]`) keeps its brackets visible in the text and only gets the
/// dimming-only [ocptFountainNoteAttribution].
///
/// This class only holds pure, side-effect-free helpers (decode text into a document, encode a
/// document back to text, and compute the metadata-update requests a live editor needs after an
/// edit): it never touches a live `Editor`, which keeps it trivial to unit test without pumping a
/// widget tree, exactly like the `OcptFountainSuperDocument` class it replaces.
class OcptWysiwygCodec {
  /// Private constructor: this class only exposes static members.
  const OcptWysiwygCodec._();

  /// The classifier used to turn a line's text into its [FountainLineType].
  static const _classifier = FountainLineClassifier();

  /// The writer used to turn a node's (display text, type, context) back into a raw source line.
  static const _lineWriter = FountainLineWriter();

  /// The parser used to turn a node's display text into styled inline runs.
  static const _inlineParser = FountainInlineParser();

  /// The serializer used to turn a node's styled inline runs back into marked-up display text.
  static const _inlineSerializer = FountainInlineSerializer();

  /// Mirrors [FountainLineClassifier]'s own (private) section-heading pattern, so a section
  /// node's display text can be recovered without re-deriving the leading `#` run's length here:
  /// see [decode]'s per-type stripping and the class doc comment on the section-level
  /// normalization [encode] accepts.
  static final RegExp _sectionPattern = RegExp(r'^(#{1,6})\s*(.*)$');

  /// Splits [text] into its source lines, normalizing `\r\n`/`\r` line endings to `\n` first (the
  /// same normalization `FountainParser.parse` applies), so folded blank-line counts and the
  /// resulting [OcptWysiwygLineMapping] agree with the rest of the editor.
  static List<String> _splitLines(String text) => text.replaceAll("\r\n", "\n").replaceAll("\r", "\n").split("\n");

  /// Decodes [text] into a fresh document: one `ParagraphNode` per non-blank source line, blank
  /// runs folded into [ocptBlankLinesBeforeMetadataKey] metadata (or, for a trailing run, into
  /// [OcptWysiwygDecodeResult.trailingBlankLines]), forcing prefixes stripped into
  /// [ocptHadForcingMarkerMetadataKey] metadata, and inline emphasis/notes converted to
  /// attributions via [FountainInlineParser.parseRuns].
  ///
  /// **Empty-document rule:** [text] with zero non-blank lines (for example `""`, or text made up
  /// only of blank lines) has nowhere to put a node at all, yet `MutableDocument` needs at least
  /// one, and a node's `blockType` is never `blank` in this model (`FountainLineWriter` refuses to
  /// write a blank-type line). This case is resolved by synthesizing a single node of type
  /// [FountainLineType.action] with empty text, unlocked and with no forcing marker, folding every
  /// blank line of the (all-blank) source into [OcptWysiwygDecodeResult.trailingBlankLines] except
  /// the one the synthesized node's own (always-empty, see [encode]'s doc comment) line stands in
  /// for. This keeps the empty-document case round-trip stable: [encode] reproduces exactly the
  /// same blank-line count.
  static OcptWysiwygDecodeResult decode(String text) {
    final lines = _splitLines(text);
    final types = _classifier.classify(lines);

    final nodes = <ParagraphNode>[];
    final blankLinesBeforeByNode = <int>[];
    var pendingBlanks = 0;

    for (var index = 0; index < lines.length; index++) {
      if (types[index] == FountainLineType.blank) {
        pendingBlanks++;
        continue;
      }

      final (displayText, hadForcingMarker) = _stripDisplayText(lines[index], types[index]);
      nodes.add(
        ParagraphNode(
          id: Editor.createNodeId(),
          text: _attributedTextFromRuns(_inlineParser.parseRuns(displayText)),
          metadata: {
            "blockType": OcptFountainLineAttributions.attributionOf(types[index]),
            ocptBlankLinesBeforeMetadataKey: pendingBlanks,
            ocptTypeLockedMetadataKey: false,
            ocptHadForcingMarkerMetadataKey: hadForcingMarker,
          },
        ),
      );
      blankLinesBeforeByNode.add(pendingBlanks);
      pendingBlanks = 0;
    }

    var trailingBlankLines = pendingBlanks;

    if (nodes.isEmpty) {
      // Every source line was blank (including the single "line" `"".split("\n")` always yields
      // for an empty string): fold all but one of them into the trailing count, since the
      // synthesized node's own (always-empty) line stands in for that one. See the doc comment
      // above.
      trailingBlankLines -= 1;
      nodes.add(
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(""),
          metadata: {
            "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.action),
            ocptBlankLinesBeforeMetadataKey: 0,
            ocptTypeLockedMetadataKey: false,
            ocptHadForcingMarkerMetadataKey: false,
          },
        ),
      );
      blankLinesBeforeByNode.add(0);
    }

    return OcptWysiwygDecodeResult(
      document: MutableDocument(nodes: nodes),
      mapping: OcptWysiwygLineMapping._build(
        sourceText: text,
        blankLinesBeforeByNode: blankLinesBeforeByNode,
        trailingBlankLines: trailingBlankLines,
      ),
      trailingBlankLines: trailingBlankLines,
    );
  }

  /// Encodes [document] back into Fountain source text, the inverse of [decode]: rejoins each
  /// node's inline attributions into marked-up display text
  /// ([FountainInlineSerializer.write]/[_runsFromAttributedText]), then lets [FountainLineWriter]
  /// decide, left to right with the already-fixed earlier lines as context, whether each node's
  /// stored `blockType` needs a forcing marker to (re-)classify correctly, honoring
  /// [ocptHadForcingMarkerMetadataKey] to preserve a marker even when auto-detection alone would
  /// already suffice. [trailingBlankLines] (normally [OcptWysiwygDecodeResult.trailingBlankLines],
  /// carried forward by the caller across a session, since nothing in this model's node structure
  /// tracks it) is appended as that many blank lines at the very end.
  ///
  /// **Empty-node rule:** a node whose display text is empty (having nothing to serialize, and
  /// nowhere to attach a forcing marker even if [ocptHadForcingMarkerMetadataKey] is set) always
  /// serializes as a plain empty source line, regardless of its stored `blockType`, **except**
  /// for [FountainLineType.pageBreak] and [FountainLineType.centeredText], whose written line
  /// never depends on a forcing-marker decision in the first place (`===` and `'> $text <'` are
  /// always emitted as-is). Without this rule, [FountainLineWriter.writeLine] would prepend a
  /// forcing marker to an otherwise-empty line for every other type whenever the empty text does
  /// not already auto-detect as that type (which an empty string never does), turning a
  /// blank-looking node into a stray marker-only source line; this way, an emptied node
  /// round-trips back to a genuinely empty line, matching the intuitive "nothing typed here"
  /// expectation and keeping the [decode]-documented empty-document synthesis round-trip stable
  /// no matter which type it picks.
  ///
  /// **Dialogue/parenthetical fallback (intentional, not a bug):** Fountain has no forcing marker
  /// for [FountainLineType.dialogue]/[FountainLineType.parenthetical] (contextual only:
  /// `FountainLineWriter` always emits their text verbatim). A dialogue or parenthetical node not
  /// immediately following a character/parenthetical/dialogue node in the written output
  /// serializes as plain text indistinguishable from action, and degrades to
  /// [FountainLineType.action] on the next [decode]. The live document can still display/lock such
  /// a node as dialogue; only its serialized Fountain text degrades.
  ///
  /// **Section-level normalization (accepted, documented):** this model does not track how many
  /// leading `#` characters a section heading originally used (only the three metadata keys this
  /// class documents exist); every section node always serializes with a single `#`, collapsing a
  /// `##`/`###`/… heading to level 1. This is a deliberate, harmless normalization in the same
  /// spirit as the dialogue fallback above (worst case, a one-time dirty flag on mode entry).
  static OcptWysiwygEncodeResult encode(Document document, {int trailingBlankLines = 0}) {
    final nodes = document.map((node) => node as ParagraphNode).toList(growable: false);

    final types = [
      for (final node in nodes) OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")),
    ];
    final displayTextByNode = [for (final node in nodes) _inlineSerializer.write(_runsFromAttributedText(node.text))];
    final blankLinesBeforeByNode = [for (final node in nodes) _readBlankLinesBefore(node)];

    // Dialogue/parenthetical have no forcing marker at all (`FountainLineWriter` always emits
    // their text verbatim): their classification depends entirely on the immediately preceding
    // *type* being a dialogue-group member, which a real blank line in between would break (the
    // preceding type would read as blank, not character/parenthetical/dialogue). A character cue
    // is not included here: unlike dialogue/parenthetical, it normally needs to be preceded by a
    // blank line (or the very start of the document) to auto-detect at all, so a real blank line
    // immediately before one (for example between two separate dialogue exchanges that both
    // happen to feature the same character, as in `MARY (O.S.)` / `STEVE` / `STEVE` / `MARY^` in
    // kitchen_sink.fountain) must be preserved, not zeroed.
    for (var index = 1; index < nodes.length; index++) {
      final continuesDialogueGroup =
          (types[index] == FountainLineType.dialogue || types[index] == FountainLineType.parenthetical) &&
          _isDialogueGroupMember(types[index - 1]);
      if (continuesDialogueGroup) {
        blankLinesBeforeByNode[index] = 0;
      }
    }

    final outputLines = <String>[];
    for (var index = 0; index < nodes.length; index++) {
      for (var blank = 0; blank < blankLinesBeforeByNode[index]; blank++) {
        outputLines.add("");
      }

      // `FountainLineType.pageBreak`/`centeredText` never derive their written line from a
      // forcing-marker decision (see the class doc comment's empty-node rule), so an empty
      // display text never risks stranding a marker there; every other type does, and always
      // serializes an empty node as a plain empty line instead.
      final displayText = displayTextByNode[index];
      final type = types[index];
      if (displayText.isEmpty && type != FountainLineType.pageBreak && type != FountainLineType.centeredText) {
        outputLines.add("");
        continue;
      }

      final hasNextNode = index + 1 < nodes.length;
      final nextNodeBlankLines = hasNextNode ? blankLinesBeforeByNode[index + 1] : trailingBlankLines;
      final nextRawLine = hasNextNode
          ? (nextNodeBlankLines > 0 ? "" : displayTextByNode[index + 1])
          : (trailingBlankLines > 0 ? "" : null);
      final previousType = blankLinesBeforeByNode[index] > 0
          ? FountainLineType.blank
          : (index == 0 ? null : types[index - 1]);

      outputLines.add(
        _lineWriter.writeLine(
          text: displayText,
          type: types[index],
          hadForcingMarker: _readHadForcingMarker(nodes[index]),
          previousType: previousType,
          nextRawLine: nextRawLine,
        ),
      );
    }

    for (var blank = 0; blank < trailingBlankLines; blank++) {
      outputLines.add("");
    }

    final text = outputLines.join("\n");
    return OcptWysiwygEncodeResult(
      text: text,
      mapping: OcptWysiwygLineMapping._build(
        sourceText: text,
        blankLinesBeforeByNode: blankLinesBeforeByNode,
        trailingBlankLines: trailingBlankLines,
      ),
    );
  }

  /// Computes the requests needed to bring every unlocked, non-empty node's `blockType` metadata
  /// back in sync with a fresh classification of [document]'s current text, given the surrounding
  /// context every other node's current text (and folded blank runs) provides.
  ///
  /// A node with [ocptTypeLockedMetadataKey] set is left untouched entirely (a future manual
  /// type choice is sticky). A node whose text is empty carries no classification signal, so its
  /// `blockType` is left untouched too; instead, if it was locked, an
  /// [OcptChangeNodeMetadataRequest] clears the lock, since architecturally a manual type choice
  /// only makes sense while the block still has content. Only a node whose classified
  /// [FountainLineType] actually changed produces a [ChangeParagraphBlockTypeRequest], which is
  /// what keeps this pass from touching (and, from the layout's perspective, recreating) every
  /// node after every edit.
  static List<EditRequest> reclassifyRequests(Document document) {
    final nodes = document.map((node) => node as ParagraphNode).toList(growable: false);

    // Reconstruct the virtual line list every node's context depends on: blank runs are real
    // nodes' metadata, not nodes, so they must be reinserted before classifying.
    final virtualLines = <String>[];
    final lineIndexOfNode = List<int>.filled(nodes.length, 0);
    for (var index = 0; index < nodes.length; index++) {
      for (var blank = 0; blank < _readBlankLinesBefore(nodes[index]); blank++) {
        virtualLines.add("");
      }
      lineIndexOfNode[index] = virtualLines.length;
      virtualLines.add(nodes[index].text.toPlainText());
    }
    final classifiedTypes = _classifier.classify(virtualLines);

    final requests = <EditRequest>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];

      if (node.text.toPlainText().isEmpty) {
        if (_readTypeLocked(node)) {
          requests.add(
            OcptChangeNodeMetadataRequest(nodeId: node.id, metadata: {ocptTypeLockedMetadataKey: false}),
          );
        }
        continue;
      }

      if (_readTypeLocked(node)) {
        continue;
      }

      final expectedAttribution = OcptFountainLineAttributions.attributionOf(classifiedTypes[lineIndexOfNode[index]]);
      final currentBlockType = node.getMetadataValue("blockType");
      if (currentBlockType is NamedAttribution && currentBlockType.name == expectedAttribution.name) {
        continue;
      }

      requests.add(ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: expectedAttribution));
    }

    return requests;
  }

  /// Computes the requests needed to bring every node's [ocptFountainNoteAttribution] spans back
  /// in sync with the `[[...]]` regions currently in its text, adding/removing spans only for a
  /// node whose desired spans actually differ from what it currently carries (so an edit outside
  /// any note leaves every node's note spans untouched).
  static List<EditRequest> noteAttributionRequests(Document document) {
    final requests = <EditRequest>[];

    for (final node in document) {
      if (node is! TextNode) {
        continue;
      }

      final plainText = node.text.toPlainText();
      final desiredRanges = _noteRanges(plainText);
      final currentRanges = node.text
          .getAttributionSpans({ocptFountainNoteAttribution})
          .map((span) => (span.start, span.end + 1))
          .toList(growable: false)
        ..sort((a, b) => a.$1.compareTo(b.$1));

      if (_sameRanges(currentRanges, desiredRanges)) {
        continue;
      }

      if (currentRanges.isNotEmpty) {
        requests.add(
          RemoveTextAttributionsRequest(
            documentRange: DocumentRange(
              start: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 0)),
              end: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: plainText.length)),
            ),
            attributions: {ocptFountainNoteAttribution},
          ),
        );
      }

      for (final (start, end) in desiredRanges) {
        requests.add(
          AddTextAttributionsRequest(
            documentRange: DocumentRange(
              start: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: start)),
              end: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: end)),
            ),
            attributions: {ocptFountainNoteAttribution},
          ),
        );
      }
    }

    return requests;
  }

  /// Whether [a] and [b] hold the same (start, exclusive end) ranges in the same order.
  static bool _sameRanges(List<(int, int)> a, List<(int, int)> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  /// The (start, exclusive end) character ranges of every `[[...]]` region in [text], left to
  /// right and non-overlapping, mirroring `FountainInlineParser.parse`'s own note-matching rule
  /// (nearest `]]` after each `[[`, no nesting).
  static List<(int, int)> _noteRanges(String text) {
    final ranges = <(int, int)>[];
    var index = 0;
    while (index < text.length) {
      final openIndex = text.indexOf("[[", index);
      if (openIndex == -1) {
        break;
      }
      final closeIndex = text.indexOf("]]", openIndex + 2);
      if (closeIndex == -1) {
        break;
      }
      ranges.add((openIndex, closeIndex + 2));
      index = closeIndex + 2;
    }
    return ranges;
  }

  /// Whether [type] is a dialogue-block element that keeps a dialogue group open (see
  /// [FountainLineClassifier]'s own equivalent private rule), used by [encode] to force
  /// [ocptBlankLinesBeforeMetadataKey] to 0 between two directly-adjacent members.
  static bool _isDialogueGroupMember(FountainLineType type) =>
      type == FountainLineType.character || type == FountainLineType.parenthetical || type == FountainLineType.dialogue;

  /// Reads a node's [ocptBlankLinesBeforeMetadataKey] metadata, defaulting to 0 for a node that
  /// never had it set (for example one freshly split off by a default super_editor command).
  static int _readBlankLinesBefore(ParagraphNode node) {
    final value = node.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
    return value is int ? value : 0;
  }

  /// Reads a node's [ocptHadForcingMarkerMetadataKey] metadata, defaulting to false.
  static bool _readHadForcingMarker(ParagraphNode node) => node.getMetadataValue(ocptHadForcingMarkerMetadataKey) == true;

  /// Reads a node's [ocptTypeLockedMetadataKey] metadata, defaulting to false.
  static bool _readTypeLocked(ParagraphNode node) => node.getMetadataValue(ocptTypeLockedMetadataKey) == true;

  /// Strips [rawLine]'s forcing prefix (if any) for its classified [type], returning its display
  /// text and whether a marker was actually present. Mirrors, in reverse, every rule
  /// [FountainLineClassifier.classifyLine] and [FountainLineWriter.writeLine] use for that type.
  static (String, bool) _stripDisplayText(String rawLine, FountainLineType type) {
    switch (type) {
      case FountainLineType.blank:
        // Never reached: blank lines are folded into ocptBlankLinesBefore before this is called.
        return (rawLine, false);
      case FountainLineType.pageBreak:
        // `FountainLineWriter` ignores the text entirely for a page break; there is nothing
        // meaningful to preserve.
        return ("", false);
      case FountainLineType.section:
        final match = _sectionPattern.firstMatch(rawLine.trim());
        return (match?.group(2) ?? "", true);
      case FountainLineType.synopsis:
        var rest = rawLine.substring(1);
        if (rest.startsWith(" ")) {
          rest = rest.substring(1);
        }
        return (rest, true);
      case FountainLineType.sceneHeading:
        return rawLine.startsWith(".") && !rawLine.startsWith("..")
            ? (rawLine.substring(1), true)
            : (rawLine, false);
      case FountainLineType.action:
        return rawLine.startsWith("!") ? (rawLine.substring(1), true) : (rawLine, false);
      case FountainLineType.character:
        return rawLine.startsWith("@") ? (rawLine.substring(1), true) : (rawLine, false);
      case FountainLineType.transition:
        return rawLine.startsWith(">") ? (rawLine.substring(1), true) : (rawLine, false);
      case FountainLineType.lyrics:
        return (rawLine.substring(1), true);
      case FountainLineType.centeredText:
        return (_stripCentered(rawLine), true);
      case FountainLineType.dialogue:
      case FountainLineType.parenthetical:
        return (rawLine, false);
    }
  }

  /// Strips the `> ` / ` <` wrapping [FountainLineWriter.writeLine] always emits for
  /// [FountainLineType.centeredText] (`'> $text <'`), tolerating the wrapping marker with or
  /// without its usual single space so a hand-written `>text<` line still recovers its inner text.
  static String _stripCentered(String rawLine) {
    final trimmed = rawLine.trim();
    if (trimmed.length < 2) {
      return "";
    }
    var body = trimmed.substring(1, trimmed.length - 1);
    if (body.startsWith(" ")) {
      body = body.substring(1);
    }
    if (body.endsWith(" ")) {
      body = body.substring(0, body.length - 1);
    }
    return body;
  }

  /// Converts [runs] into an `AttributedText`, applying [boldAttribution], [italicsAttribution],
  /// [underlineAttribution] and [ocptFountainNoteAttribution] over each run's span; the inverse of
  /// [_runsFromAttributedText].
  static AttributedText _attributedTextFromRuns(List<FountainStyledRun> runs) {
    final buffer = StringBuffer();
    final spans = <(int, int, Attribution)>[];

    for (final run in runs) {
      final start = buffer.length;
      buffer.write(run.text);
      final end = buffer.length - 1;
      if (end < start) {
        continue;
      }
      if (run.isBold) {
        spans.add((start, end, boldAttribution));
      }
      if (run.isItalic) {
        spans.add((start, end, italicsAttribution));
      }
      if (run.isUnderline) {
        spans.add((start, end, underlineAttribution));
      }
      if (run.isNote) {
        spans.add((start, end, ocptFountainNoteAttribution));
      }
    }

    final attributedText = AttributedText(buffer.toString());
    for (final (start, end, attribution) in spans) {
      attributedText.addAttribution(attribution, SpanRange(start, end));
    }
    return attributedText;
  }

  /// Converts [text]'s attributions into [FountainStyledRun]s, splitting it wherever its bold,
  /// italic, underline or note attribution set changes; the inverse of [_attributedTextFromRuns].
  ///
  /// An [ocptFountainNoteAttribution] range always wins over any overlapping bold/italic/underline
  /// attribution (dropped at this point): a note is atomic in Fountain, so emphasis can never
  /// survive inside one on serialization.
  static List<FountainStyledRun> _runsFromAttributedText(AttributedText text) {
    final plainText = text.toPlainText();
    if (plainText.isEmpty) {
      return const [];
    }

    (bool, bool, bool, bool) styleAt(int offset) {
      final attributions = text.getAllAttributionsAt(offset);
      final isNote = attributions.contains(ocptFountainNoteAttribution);
      return (
        !isNote && attributions.contains(boldAttribution),
        !isNote && attributions.contains(italicsAttribution),
        !isNote && attributions.contains(underlineAttribution),
        isNote,
      );
    }

    final runs = <FountainStyledRun>[];
    var runStart = 0;
    var currentStyle = styleAt(0);
    for (var offset = 1; offset <= plainText.length; offset++) {
      final style = offset < plainText.length ? styleAt(offset) : null;
      if (style == currentStyle) {
        continue;
      }

      runs.add(
        FountainStyledRun(
          text: plainText.substring(runStart, offset),
          isBold: currentStyle.$1,
          isItalic: currentStyle.$2,
          isUnderline: currentStyle.$3,
          isNote: currentStyle.$4,
        ),
      );
      runStart = offset;
      if (style != null) {
        currentStyle = style;
      }
    }

    return runs;
  }
}
