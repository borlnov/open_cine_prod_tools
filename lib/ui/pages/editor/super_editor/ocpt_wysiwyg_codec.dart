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

/// The number of [ocptBlankLinesBeforeMetadataKey] blank lines above which extra spacing stops
/// growing: beyond a few blank lines, one more doesn't need to visually register any bigger a gap
/// than the last. Shared by `OcptFountainEditorStylesheet` (the padding it actually renders) and
/// `computeOcptStyledPagination` (the line budget pagination counts against), so the two stay in
/// sync.
const int ocptMaxBlankLinesBeforeSpacing = 3;

/// The `ParagraphNode` metadata key holding whether a node's `blockType` was set manually (a
/// dropdown/Tab choice) rather than by auto-detection; [OcptWysiwygCodec.reclassifyRequests]
/// skips a locked node entirely and never clears the lock on its own, so the manual choice is
/// sticky for the node's whole lifetime, including while its text is empty. A new node created by
/// Enter/Shift+Enter starts unlocked, which is what keeps a locked type from leaking into the next
/// block.
const String ocptTypeLockedMetadataKey = "ocptTypeLocked";

/// The `ParagraphNode` metadata key holding whether the source line a node was decoded from used
/// an explicit forcing marker, so [OcptWysiwygCodec.encode] can re-emit it even when
/// auto-detection alone would already yield the same type (byte-stable round trips).
const String ocptHadForcingMarkerMetadataKey = "ocptHadForcingMarker";

/// The `ParagraphNode` metadata key holding a scene heading's explicit `#N#` scene number (the
/// text between the `#` delimiters, e.g. `"4A"` for `#4A#`), or null for a heading with none.
///
/// Only ever set on a [FountainLineType.sceneHeading] node. [OcptWysiwygCodec.decode] strips a
/// trailing `#N#` tag out of the heading's display text into this metadata, and
/// [OcptWysiwygCodec.encode] re-appends it to the written line, so the tag never shows up as
/// literal text in the styled editor while still surviving a round trip; a tag typed live is
/// absorbed the same way by [OcptWysiwygCodec.sceneNumberRequests]. Rendering the number (styled
/// mode only) is a separate concern, driven by `computeOcptStyledSceneNumbers`.
const String ocptSceneNumberMetadataKey = "ocptSceneNumber";

/// The `ParagraphNode` metadata key holding which title-page field a node represents (one of
/// [ocptTitlePageFieldKeys]), or absent for an ordinary body line.
///
/// Only ever set by [OcptWysiwygCodec.decodeWithTitlePage] (and the keyboard action that keeps a
/// title-page field's own Enter gesture continuing the same field, `_splitTitlePageField` in
/// `ocpt_fountain_keyboard_actions.dart`): none of the ordinary Fountain line machinery this class
/// documents (auto-detection, forcing markers, uppercasing, scene numbers…) ever applies to a node
/// carrying it, which is what [OcptWysiwygCodec.isTitlePageNode] lets every one of those passes
/// check for and skip.
const String ocptTitlePageKeyMetadataKey = "ocptTitlePageKey";

/// The `blockType` attribution shared by every title-page field node, regardless of which field it
/// represents ([ocptTitlePageKeyMetadataKey] carries that distinction instead): a title-page field
/// is never classified, never forced, never uppercased, so it needs no per-field attribution the
/// way every [FountainLineType] gets its own in [OcptFountainLineAttributions] — only a stylesheet
/// selector to opt into `OcptFountainEditorStylesheet`'s own per-field positioning.
const NamedAttribution ocptTitlePageFieldAttribution = NamedAttribution("fountainTitlePageField");

/// The six canonical title-page field keys [OcptWysiwygCodec.decodeWithTitlePage] always
/// synthesizes exactly one node for (more if a field spans several source lines), in the fixed
/// order they are written to the source and stacked top-to-bottom in the styled editor — matching
/// the order `OcptEditorTitlePageDialog`'s `⋮ ▸ Title page…` fields already appear in
/// (`editor_bloc.dart`'s `_titlePageEntriesFrom`), so editing the same screenplay through either
/// front-end never reorders the block for no reason.
const List<String> ocptTitlePageFieldKeys = ["Title", "Credit", "Author", "Draft date", "Contact", "Source"];

/// The attribution marking an inline authoring note (`[[text]]`) for dimmed rendering; unlike
/// [boldAttribution]/[italicsAttribution]/[underlineAttribution], a note's delimiters stay part of
/// its node's plain text (see [FountainStyledRun.isNote]), so this attribution is only ever used
/// for styling, never for serialization (a node's text already carries the brackets verbatim).
const NamedAttribution ocptFountainNoteAttribution = NamedAttribution("fountainNote");

/// The result of [OcptWysiwygCodec.decode]: everything a caller needs to display a freshly decoded
/// document and later serialize it back to Fountain text.
class OcptWysiwygDecodeResult {
  /// Creates an [OcptWysiwygDecodeResult].
  const OcptWysiwygDecodeResult({
    required this.document,
    required this.mapping,
    required this.trailingBlankLines,
    this.titlePageNodeCount = 0,
    this.titlePagePrefixLength = 0,
  });

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

  /// The number of leading characters of the full source text [OcptWysiwygCodec.decodeWithTitlePage]
  /// was given that the title page (and the blank line separating it from the body) consumed,
  /// always 0 for a plain [OcptWysiwygCodec.decode] result. A caller translating a character offset
  /// of the full source text into a [mapping] char offset must subtract this first.
  final int titlePagePrefixLength;
}

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

  /// Mirrors `FountainBlockBuilder`'s own (private) scene-number pattern, matching a trailing
  /// `#N#` tag on a scene heading line (e.g. `#4A#` in `INT. HOUSE #4A#`), captured as group 1.
  static final RegExp _sceneNumberPattern = RegExp(r'#([A-Za-z0-9.\-]+)#\s*$');

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
    final (nodes, blankLinesBeforeByNode, pendingBlanks) = _decodeLines(lines);

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

  /// Decodes [text] exactly like [decode], but additionally recognizes a leading title page (see
  /// `FountainParser`'s own title-page pre-pass) and prepends one node per
  /// [ocptTitlePageFieldKeys] field ([isTitlePageNode], carrying [ocptTitlePageKeyMetadataKey])
  /// ahead of the body nodes [decode] itself would already produce for the remaining text.
  ///
  /// Every one of the six canonical fields always gets at least one node, synthesized empty when
  /// the source has no title page at all (or is simply missing that field): the styled editor's
  /// title sheet must always be a complete, fillable page, per its own design (see
  /// `OcptStyledScreenplayEditor`'s class doc comment). A field spanning several source lines
  /// (an `Author`/`Contact` continuation) gets one node per line instead, in source order, so
  /// pressing Enter inside one only ever needs to insert a sibling node of the same field (see
  /// `_splitTitlePageField` in `ocpt_fountain_keyboard_actions.dart`) rather than reformat the
  /// whole field.
  ///
  /// [OcptWysiwygDecodeResult.mapping] stays scoped to the body text alone (built by the plain
  /// [decode] call this delegates to for it), which is why [OcptWysiwygDecodeResult
  /// .titlePageNodeCount]/[OcptWysiwygDecodeResult.titlePagePrefixLength] exist: they are what a
  /// caller needs to translate one of [OcptWysiwygDecodeResult.document]'s own node indices, or a
  /// char offset into the *full* [text], into that body-scoped mapping's own coordinate space.
  static OcptWysiwygDecodeResult decodeWithTitlePage(String text) {
    final titlePage = const FountainParser().parse(text).titlePage;
    final bodyText = titlePage == null
        ? text
        : const FountainTitlePageWriter().apply(source: text, existingRange: titlePage.sourceRange, entries: const []);

    final titlePageNodes = _titlePageNodesFrom(titlePage);
    final bodyDecoded = decode(bodyText);

    return OcptWysiwygDecodeResult(
      document: MutableDocument(
        nodes: [...titlePageNodes, ...bodyDecoded.document.map((node) => node as ParagraphNode)],
      ),
      mapping: bodyDecoded.mapping,
      trailingBlankLines: bodyDecoded.trailingBlankLines,
      titlePageNodeCount: titlePageNodes.length,
      titlePagePrefixLength: text.length - bodyText.length,
    );
  }

  /// Decodes [text] into the nodes a paste would insert, with the full metadata set [decode]
  /// itself gives every node (`blockType`, [ocptBlankLinesBeforeMetadataKey],
  /// [ocptTypeLockedMetadataKey] always false, [ocptHadForcingMarkerMetadataKey]) — unlike
  /// [decode], this never synthesizes an empty node for all-blank input, since there is nothing
  /// useful to paste in that case: the caller sees an empty list instead.
  static List<ParagraphNode> decodeNodesFromFountain(String text) {
    final (nodes, _, _) = _decodeLines(_splitLines(text));
    return nodes;
  }

  /// The shared per-line decoding loop behind [decode] and [decodeNodesFromFountain]: turns
  /// [lines] into one node per non-blank line (folding blank runs into
  /// [ocptBlankLinesBeforeMetadataKey] metadata) plus, in call order, the resulting nodes, their
  /// blank-lines-before counts (same length, same order as the nodes) and the number of blank
  /// lines still pending after the last non-blank line (the trailing run [decode] alone turns
  /// into [OcptWysiwygDecodeResult.trailingBlankLines]).
  static (List<ParagraphNode>, List<int>, int) _decodeLines(List<String> lines) {
    final types = _classifier.classify(lines);

    final nodes = <ParagraphNode>[];
    final blankLinesBeforeByNode = <int>[];
    var pendingBlanks = 0;

    for (var index = 0; index < lines.length; index++) {
      if (types[index] == FountainLineType.blank) {
        pendingBlanks++;
        continue;
      }

      final (strippedText, hadForcingMarker) = _stripDisplayText(lines[index], types[index]);
      final (displayText, sceneNumber) = types[index] == FountainLineType.sceneHeading
          ? _extractSceneNumber(strippedText)
          : (strippedText, null);
      nodes.add(
        ParagraphNode(
          id: Editor.createNodeId(),
          text: _attributedTextFromRuns(_inlineParser.parseRuns(displayText)),
          metadata: {
            "blockType": OcptFountainLineAttributions.attributionOf(types[index]),
            ocptBlankLinesBeforeMetadataKey: pendingBlanks,
            ocptTypeLockedMetadataKey: false,
            ocptHadForcingMarkerMetadataKey: hadForcingMarker,
            ocptSceneNumberMetadataKey: sceneNumber,
          },
        ),
      );
      blankLinesBeforeByNode.add(pendingBlanks);
      pendingBlanks = 0;
    }

    return (nodes, blankLinesBeforeByNode, pendingBlanks);
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
    final displayTextByNode = [
      for (var index = 0; index < nodes.length; index++)
        _displayTextForEncode(nodes[index], types[index]),
    ];
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

  /// Encodes [document] exactly like [encode], but additionally recognizes [document]'s leading
  /// title-page field nodes ([isTitlePageNode]) and splices them in as a real Fountain title page
  /// ahead of the body text [encode] itself produces for the remaining nodes, through
  /// [FountainTitlePageWriter.apply] — never a hand-written `Key: value` line, so this and
  /// `OcptEditorTitlePageDialog`'s `⋮ ▸ Title page…` flow stay two front-ends over the one writer.
  /// A field with only empty lines (the common case for most of the six: see
  /// [decodeWithTitlePage]'s synthesis rule) is dropped entirely, exactly like
  /// [FountainTitlePageWriter.apply] drops a title page with no entries at all.
  ///
  /// See [OcptWysiwygEncodeResult.titlePageNodeCount]/[OcptWysiwygEncodeResult
  /// .titlePagePrefixLength]'s own doc comments for what a caller needs them for.
  static OcptWysiwygEncodeResult encodeWithTitlePage(Document document, {int trailingBlankLines = 0}) {
    final allNodes = document.map((node) => node as ParagraphNode).toList(growable: false);
    final titlePageNodes = <ParagraphNode>[];
    final bodyNodes = <ParagraphNode>[];
    for (final node in allNodes) {
      (isTitlePageNode(node) ? titlePageNodes : bodyNodes).add(node);
    }

    final bodyEncoded = encode(MutableDocument(nodes: bodyNodes), trailingBlankLines: trailingBlankLines);
    final titlePageEntries = _titlePageEntriesFromNodes(titlePageNodes);
    final text = const FountainTitlePageWriter().apply(
      source: bodyEncoded.text,
      existingRange: null,
      entries: titlePageEntries,
    );

    return OcptWysiwygEncodeResult(
      text: text,
      mapping: bodyEncoded.mapping,
      titlePageNodeCount: titlePageNodes.length,
      titlePagePrefixLength: text.length - bodyEncoded.text.length,
    );
  }

  /// Whether [node] is one of [decodeWithTitlePage]'s synthesized title-page field nodes
  /// ([ocptTitlePageKeyMetadataKey] set) rather than an ordinary body line: every pass in this
  /// class that classifies, forces or uppercases a node's text (none of which has any meaning for
  /// a title-page field) checks this first and skips the node entirely when it's true.
  static bool isTitlePageNode(ParagraphNode node) => node.getMetadataValue(ocptTitlePageKeyMetadataKey) is String;

  /// The title page entry for [key] (`Author` also matching a source written as `Authors`, per
  /// `FountainTitlePage.authors`'s own fallback), or null when [titlePage] is null or has no such
  /// entry.
  static FountainTitlePageEntry? _titlePageEntryFor(FountainTitlePage? titlePage, String key) {
    if (titlePage == null) {
      return null;
    }
    return key == "Author" ? (titlePage.entry("Author") ?? titlePage.entry("Authors")) : titlePage.entry(key);
  }

  /// A placeholder source range for a title-page entry synthesized from live node text rather than
  /// parsed from source: [FountainTitlePageWriter.apply] only ever reads an entry's key and values,
  /// never its source range (see `editor_bloc.dart`'s own equivalent placeholder), so standing in
  /// without a real one is safe.
  static const _placeholderTitlePageEntryRange = FountainSourceRange(
    startLine: 0,
    endLine: 0,
    startOffset: 0,
    endOffset: 0,
  );

  /// Builds the title-page field nodes [decodeWithTitlePage] prepends to the body: one node per
  /// [ocptTitlePageFieldKeys] field, in that fixed order, one per source line for a field spanning
  /// several (an empty single node when [titlePage] has none for that key at all).
  ///
  /// The sheet is protected against every deletion path — select-all + Delete, a selection dragged
  /// across the sheet, Backspace merging a field into its neighbour — by
  /// `ocptTitlePageGuardRequestHandler` (`ocpt_title_page_guard_requests.dart`) alone: a node here
  /// deliberately does **not** carry `NodeMetadata.isDeletable: false`, which would also forbid
  /// ordinary text editing (typing, Backspace, Delete) *inside* the field, not just its removal
  /// (`DeleteSelectionCommand`/`DeleteContentCommand` abort any deletion, however small, contained
  /// in a single non-deletable node — `multi_node_editing.dart:1428-1449, 798-822` of the pinned
  /// super_editor release).
  static List<ParagraphNode> _titlePageNodesFrom(FountainTitlePage? titlePage) {
    final nodes = <ParagraphNode>[];
    for (final key in ocptTitlePageFieldKeys) {
      final entry = _titlePageEntryFor(titlePage, key);
      final values = entry == null || entry.values.isEmpty ? const [""] : entry.values;
      for (final value in values) {
        nodes.add(
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(value),
            metadata: {"blockType": ocptTitlePageFieldAttribution, ocptTitlePageKeyMetadataKey: key},
          ),
        );
      }
    }
    return nodes;
  }

  /// The inverse of [_titlePageNodesFrom]: groups [titlePageNodes] (already in the fixed
  /// [ocptTitlePageFieldKeys] order, one run of consecutive nodes per field, by construction) back
  /// into [FountainTitlePageEntry] values, dropping a field whose every line is empty (the common
  /// case for most fields most of the time) so [FountainTitlePageWriter.apply] never writes a
  /// stray `Key:` line with nothing after it.
  static List<FountainTitlePageEntry> _titlePageEntriesFromNodes(List<ParagraphNode> titlePageNodes) {
    final entries = <FountainTitlePageEntry>[];
    String? currentKey;
    var currentValues = <String>[];

    void flush() {
      final key = currentKey;
      if (key != null) {
        final nonEmptyValues = currentValues.where((value) => value.trim().isNotEmpty).toList(growable: false);
        if (nonEmptyValues.isNotEmpty) {
          entries.add(
            FountainTitlePageEntry(key: key, values: nonEmptyValues, sourceRange: _placeholderTitlePageEntryRange),
          );
        }
      }
      currentKey = null;
      currentValues = [];
    }

    for (final node in titlePageNodes) {
      final key = node.getMetadataValue(ocptTitlePageKeyMetadataKey);
      if (key is! String) {
        continue;
      }
      if (key != currentKey) {
        flush();
        currentKey = key;
      }
      currentValues.add(node.text.toPlainText());
    }
    flush();

    return entries;
  }

  /// Encodes just the [selection] span of [document] into Fountain source text, for the
  /// clipboard: reuses [encode] on a throwaway document holding only the selected nodes (clipping
  /// the first and last node's text to the selection's own start/end offsets, attributions
  /// preserved), so a copied fragment stays a faithful, independently round-trippable Fountain
  /// excerpt — decodable again by [decodeNodesFromFountain] on paste, or by [decode] if pasted
  /// into another Fountain-aware target. The first node's [ocptBlankLinesBeforeMetadataKey] is
  /// forced to 0 so a copied fragment never starts with leading blank lines; every other node
  /// keeps its own metadata untouched, including its blank-lines-before count, so the spacing
  /// between the copied lines survives.
  static String encodeSelectionToFountain(Document document, DocumentSelection selection) {
    final nodes = _clippedSelectionNodes(document, selection);
    if (nodes.isEmpty) {
      return "";
    }

    final adjustedNodes = [
      nodes.first.copyWithAddedMetadata({ocptBlankLinesBeforeMetadataKey: 0}),
      ...nodes.skip(1),
    ];
    return encode(MutableDocument(nodes: adjustedNodes)).text;
  }

  /// The [ParagraphNode]s [selection] spans in [document], in document order, with the first and
  /// last node's text clipped to the selection's own start/end offsets (a selection collapsed to
  /// a single node clips both ends of that one node). A non-[ParagraphNode] inside the span (none
  /// exist in this model today, but [Document.getNodesInside]'s contract allows any [DocumentNode]
  /// type) is skipped rather than crashing, since it carries nothing this codec can serialize.
  static List<ParagraphNode> _clippedSelectionNodes(Document document, DocumentSelection selection) {
    final range = selection.normalize(document);
    final startPosition = range.start.nodePosition;
    final endPosition = range.end.nodePosition;
    if (startPosition is! TextNodePosition || endPosition is! TextNodePosition) {
      return const [];
    }

    final nodes = document.getNodesInside(range.start, range.end).whereType<ParagraphNode>().toList(growable: false);
    if (nodes.isEmpty) {
      return const [];
    }

    return [
      for (var index = 0; index < nodes.length; index++)
        _clipNode(
          nodes[index],
          startOffset: range.start.nodeId == nodes[index].id ? startPosition.offset : 0,
          endOffset: range.end.nodeId == nodes[index].id ? endPosition.offset : null,
        ),
    ];
  }

  /// A copy of [node] whose text is clipped to `[startOffset, endOffset)` (or to the end of the
  /// text when [endOffset] is null), attributions preserved; every other field, including
  /// metadata, is left untouched.
  static ParagraphNode _clipNode(ParagraphNode node, {required int startOffset, int? endOffset}) {
    final clippedText = endOffset != null ? node.text.copyText(startOffset, endOffset) : node.text.copyText(startOffset);
    return node.copyParagraphWith(text: clippedText);
  }

  /// Computes the requests needed to bring every unlocked, non-empty node's `blockType` metadata
  /// back in sync with a fresh classification of [document]'s current text, given the surrounding
  /// context every other node's current text (and folded blank runs) provides.
  ///
  /// A node with [ocptTypeLockedMetadataKey] set is left untouched entirely, for its whole
  /// lifetime (a manual type choice is sticky, even across the node's text being emptied and
  /// retyped). A node whose text is empty carries no classification signal, so its `blockType` is
  /// left untouched too. Only a node whose classified [FountainLineType] actually changed produces
  /// a [ChangeParagraphBlockTypeRequest], which is what keeps this pass from touching (and, from
  /// the layout's perspective, recreating) every node after every edit.
  ///
  /// **Why a pinned node needs a marker re-emitted before classifying (the whole point of
  /// [_virtualLineForNode]):** a node's text is its *display* text, i.e. already stripped of
  /// whatever forcing marker its source line used (see the class doc comment). A type that only
  /// exists because of a marker — forced scene heading (`.`), forced action (`!`), forced
  /// character (`@`), transition (`>`), section (`#`), synopsis (`=`), lyrics (`~`), centered text
  /// (`> <`) — therefore classifies its *bare* display text back to some other, unrelated type
  /// (typically [FountainLineType.action]): feeding the classifier the stripped text is asking it
  /// to reconstruct information it was never given. Left uncorrected that wrong classification
  /// would not just mis-render once: [encode] would bake it into the source as a genuine,
  /// re-emitted forcing marker (`!SALON - JOUR`), which the very next [decode] reads back as a
  /// sticky, user-authored choice — a one-time misclassification permanently corrupting the line.
  /// [_virtualLineForNode] avoids this by re-deriving, for a pinned node only, the exact source
  /// line its marker would produce, so the classifier is asked the question it can actually
  /// answer. A side effect worth calling out: a pinned node now always classifies back to its own
  /// stored type by construction, so it never produces a request of its own — which is the
  /// correct, self-consistent outcome, not a coincidence of the check below.
  static List<EditRequest> reclassifyRequests(Document document) {
    // Title-page field nodes are filtered out before building the virtual line list below (not
    // just skipped when generating a request for them): their text has no place in the body's own
    // classification context (a real body node's auto-detection must never depend on what a title
    // field happens to hold).
    final nodes = document
        .map((node) => node as ParagraphNode)
        .where((node) => !isTitlePageNode(node))
        .toList(growable: false);
    final types = [
      for (final node in nodes) OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")),
    ];

    // Reconstruct the virtual line list every node's context depends on: blank runs are real
    // nodes' metadata, not nodes, so they must be reinserted before classifying.
    final virtualLines = <String>[];
    final lineIndexOfNode = List<int>.filled(nodes.length, 0);
    for (var index = 0; index < nodes.length; index++) {
      for (var blank = 0; blank < _readBlankLinesBefore(nodes[index]); blank++) {
        virtualLines.add("");
      }
      lineIndexOfNode[index] = virtualLines.length;
      virtualLines.add(_virtualLineForNode(nodes[index], types[index]));
    }
    final classifiedTypes = _classifier.classify(virtualLines);

    final requests = <EditRequest>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];

      if (node.text.toPlainText().isEmpty) {
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

  /// Computes the requests needed to absorb a trailing `#N#` tag typed live into a scene heading
  /// node's text: strips it from the node's text (an [OcptReplaceNodeTextRequest]) and stores the
  /// captured number as [ocptSceneNumberMetadataKey] metadata (an [OcptChangeNodeMetadataRequest]),
  /// so the tag never lingers as literal, visible text in the styled view.
  ///
  /// Only scene-heading nodes are considered. Run this pass, and execute its requests, *before*
  /// [reclassifyRequests]/[uppercaseRequests] are even computed (see the call site in
  /// `OcptStyledScreenplayEditor._syncAfterEdit`): otherwise a request from this pass and one from
  /// [uppercaseRequests], both computed against the same pre-strip text, would each replace the
  /// node's text wholesale, and whichever executes last would silently undo the other.
  static List<EditRequest> sceneNumberRequests(Document document) {
    final requests = <EditRequest>[];

    for (final node in document) {
      if (node is! ParagraphNode || isTitlePageNode(node)) {
        continue;
      }

      final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
      if (type != FountainLineType.sceneHeading) {
        continue;
      }

      final plainText = node.text.toPlainText();
      final match = _sceneNumberPattern.firstMatch(plainText);
      if (match == null) {
        continue;
      }

      final strippedLength = plainText.substring(0, match.start).trimRight().length;
      requests.add(OcptReplaceNodeTextRequest(nodeId: node.id, text: node.text.copyText(0, strippedLength)));
      requests.add(
        OcptChangeNodeMetadataRequest(nodeId: node.id, metadata: {ocptSceneNumberMetadataKey: match.group(1)}),
      );
    }

    return requests;
  }

  /// The [FountainLineType]s Fountain (and Final Draft) auto-detection expects in uppercase, and
  /// whose *stored* text this app therefore uppercases as the user types, not just its display.
  static const Set<FountainLineType> _uppercasedTypes = {
    FountainLineType.sceneHeading,
    FountainLineType.character,
    FountainLineType.transition,
  };

  /// Computes the requests needed to uppercase the text of every node currently classified as one
  /// of [_uppercasedTypes] whose text isn't already fully uppercase, preserving its attribution
  /// spans and (since uppercasing is 1:1 for the app's locales, leaving every character's offset
  /// unchanged) the caret position.
  static List<EditRequest> uppercaseRequests(Document document) {
    final requests = <EditRequest>[];

    for (final node in document) {
      if (node is! ParagraphNode || isTitlePageNode(node)) {
        continue;
      }

      final blockType = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
      if (!_uppercasedTypes.contains(blockType)) {
        continue;
      }

      final plainText = node.text.toPlainText();
      final upperText = plainText.toUpperCase();
      if (upperText == plainText) {
        continue;
      }

      requests.add(OcptReplaceNodeTextRequest(nodeId: node.id, text: _uppercased(node.text, upperText)));
    }

    return requests;
  }

  /// Copies [text]'s attribution spans and placeholders onto [upperText] unchanged: uppercasing
  /// never changes a string's length for this app's supported locales, so every span's (start, end)
  /// offset still refers to the same run of characters.
  static AttributedText _uppercased(AttributedText text, String upperText) =>
      AttributedText(upperText, text.spans.copy(), text.placeholders);

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

  /// Reads a node's [ocptSceneNumberMetadataKey] metadata, or null if it isn't set.
  static String? _readSceneNumber(ParagraphNode node) {
    final value = node.getMetadataValue(ocptSceneNumberMetadataKey);
    return value is String ? value : null;
  }

  /// The text [encode] hands to [_lineWriter] for [node]: its inline-serialized display text,
  /// with a scene heading's [ocptSceneNumberMetadataKey] tag re-appended when set. Never appends
  /// to an empty base text, so an emptied heading still serializes through the empty-node rule
  /// (a plain blank line) rather than stranding a lone `#N#` tag.
  static String _displayTextForEncode(ParagraphNode node, FountainLineType type) {
    final base = _inlineSerializer.write(_runsFromAttributedText(node.text));
    if (type != FountainLineType.sceneHeading || base.isEmpty) {
      return base;
    }

    final sceneNumber = _readSceneNumber(node);
    return sceneNumber == null ? base : "$base #$sceneNumber#";
  }

  /// Reads a node's [ocptTypeLockedMetadataKey] metadata, defaulting to false.
  static bool _readTypeLocked(ParagraphNode node) => node.getMetadataValue(ocptTypeLockedMetadataKey) == true;

  /// Whether [node]'s stored `blockType` is pinned by the user rather than up for
  /// auto-detection, per [reclassifyRequests]'s doc comment: either a manual dropdown/Tab choice
  /// ([ocptTypeLockedMetadataKey]) or a source line that carried an explicit forcing marker
  /// ([ocptHadForcingMarkerMetadataKey]) — the *serialized* form of that very same "the user fixed
  /// this type on purpose" intent, already honoured by [encode] and, until this method existed,
  /// silently ignored by [reclassifyRequests].
  static bool _isPinnedNode(ParagraphNode node) => _readTypeLocked(node) || _readHadForcingMarker(node);

  /// The virtual source line [reclassifyRequests] feeds the classifier for [node], currently
  /// stored as [type]. A pinned node (see [_isPinnedNode]) gets its marker re-emitted through
  /// [_lineWriter] with `hadForcingMarker: true`, which always prepends the marker regardless of
  /// what auto-detection alone would decide (`FountainLineWriter`'s own private
  /// `_writeWithPrefixMarker` helper only skips the marker when auto-detection agrees *and* no
  /// forcing marker was requested); `previousType`/`nextRawLine` are therefore irrelevant to the
  /// result and passed as `null`, deliberately. Every other node's virtual line is just its plain
  /// display text, exactly what auto-detection sees while the user types.
  ///
  /// An empty display text always falls back to the plain (empty) text, pinned or not:
  /// [FountainLineWriter.writeLine] refuses [FountainLineType.blank], which a node's stored type
  /// never is, but calling it on an empty string would still prepend a lone marker (e.g. `.`) with
  /// nothing after it, fabricating a virtual "line" made purely of punctuation instead of the
  /// harmless empty line a genuinely empty node should contribute.
  static String _virtualLineForNode(ParagraphNode node, FountainLineType type) {
    final displayText = node.text.toPlainText();
    if (displayText.isEmpty || !_isPinnedNode(node)) {
      return displayText;
    }

    return _lineWriter.writeLine(
      text: displayText,
      type: type,
      hadForcingMarker: true,
      previousType: null,
      nextRawLine: null,
    );
  }

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

  /// Strips a trailing `#N#` scene-number tag off a scene heading's already forcing-marker-
  /// stripped [text], returning the text without it (trailing whitespace trimmed) and the
  /// captured number, or [text] unchanged and null when there is no tag.
  static (String, String?) _extractSceneNumber(String text) {
    final match = _sceneNumberPattern.firstMatch(text);
    if (match == null) {
      return (text, null);
    }
    return (text.substring(0, match.start).trimRight(), match.group(1));
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
