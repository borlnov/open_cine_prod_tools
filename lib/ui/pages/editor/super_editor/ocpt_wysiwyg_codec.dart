// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_decode_result.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_decoder.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_document_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_dual_dialogue.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_encode_result.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_line_mapping.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_markers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_notes.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_selection_clip.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_title_page.dart';
import 'package:super_editor/super_editor.dart';

export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_decode_result.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_dual_dialogue.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_encode_result.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart'
    show
        ocptFountainCommentAttribution,
        ocptFountainEscapedAttribution,
        ocptFountainNoteAttribution;
export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_line_mapping.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_notes.dart'
    show OcptWysiwygNoteEdit;
export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_title_page.dart'
    show
        ocptTitlePageExtraEntriesMetadataKey,
        ocptTitlePageFieldAttribution,
        ocptTitlePageFieldKeys,
        ocptTitlePageKeyMetadataKey;

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

/// The `ParagraphNode` metadata key holding a section's heading level (1 to 6, the length of the
/// `#` run its source line opened with), which [OcptWysiwygCodec.encode] writes back. Only set on a
/// [FountainLineType.section] node; a missing or invalid value reads as 1.
const String ocptSectionLevelMetadataKey = "ocptSectionLevel";

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

/// Convert between Fountain source text and the super_editor `MutableDocument` backing the
/// styled block editor, on the invariant the whole styled editing mode is built around: **one
/// `ParagraphNode` per non-blank Fountain source line**, but for the lines a note running over
/// several of them covers, which one node holds together (see [OcptWysiwygDecoder.decodeLines]).
/// Blank source lines carry no node of their
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
/// dimming-only [ocptFountainNoteAttribution]. **Every node, inert or live, holds its text in that
/// one form**, and is written back through the one serializer.
///
/// **Inert lines:** a node whose whole text lies inside a commented span (a boneyard or a note,
/// possibly running over several lines: `FountainCommentSpans`) is inert, the way the parser sees
/// no screenplay element there. Whether a node is inert is recomputed from the nodes' plain texts
/// on every pass, never stored. An inert node differs from a live one only by its type (action, no
/// marker stripped on decode and none added on encode), by being left alone by the reclassify,
/// uppercase and numbering passes, and by being dimmed. The lines around it are classified on the
/// same blanked-out lines the parser classifies, so the editor and the parser agree on their types.
///
/// This class only holds pure, side-effect-free helpers (decode text into a document, encode a
/// document back to text, and compute the metadata-update requests a live editor needs after an
/// edit): it never touches a live `Editor`, which keeps it trivial to unit test without pumping a
/// widget tree, exactly like the `OcptFountainSuperDocument` class it replaces.
class OcptWysiwygCodec {
  /// The classifier used to turn a line's text into its [FountainLineType].
  static const _classifier = FountainLineClassifier();

  /// The writer used to turn a node's (display text, type, context) back into a raw source line.
  static const _lineWriter = FountainLineWriter();

  /// The serializer used to turn a node's styled inline runs back into marked-up display text.
  static const _inlineSerializer = FountainInlineSerializer();

  /// The [FountainLineType]s Fountain (and Final Draft) auto-detection expects in uppercase, and
  /// whose *stored* text this app therefore uppercases as the user types, not just its display.
  static const Set<FountainLineType> _uppercasedTypes = {
    FountainLineType.sceneHeading,
    FountainLineType.character,
    FountainLineType.transition,
  };

  /// Private constructor: this class only exposes static members.
  const OcptWysiwygCodec._();

  /// Decode [text] into a fresh document: one `ParagraphNode` per non-blank source line, blank
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
    final (nodes, blankLinesBeforeByNode, lineCountByNode, pendingBlanks) =
        OcptWysiwygDecoder.decodeLines(lines);

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
      lineCountByNode.add(1);
    }

    return OcptWysiwygDecodeResult(
      // `List<DocumentNode>.of`, not the `List<ParagraphNode>` `nodes` already is, and this is the
      // reason every `MutableDocument(nodes: ...)` in this class and in
      // `OcptStyledScreenplayEditor` states its element type too. `MutableDocument`'s `nodes:`
      // parameter is typed `List<DocumentNode>?`, but Dart's generics are reified, so a narrower
      // list keeps its own runtime type on the field the constructor stores it in. `Editor.undo()`
      // replays by resetting every `Editable`, and `MutableDocument.reset()` does
      // `_nodes..clear()..addAll(_latestNodesSnapshot)`, where `_latestNodesSnapshot` — built by
      // the constructor itself — is a genuine `List<DocumentNode>`: that `addAll` throws
      // `type 'List<DocumentNode>' is not a subtype of type 'Iterable<ParagraphNode>'` *after* the
      // `clear()` has already run, so the document is left permanently empty rather than merely
      // un-undone.
      document: MutableDocument(nodes: List<DocumentNode>.of(nodes)),
      mapping: OcptWysiwygLineMapping.build(
        sourceText: text,
        blankLinesBeforeByNode: blankLinesBeforeByNode,
        trailingBlankLines: trailingBlankLines,
        lineCountByNode: lineCountByNode,
      ),
      trailingBlankLines: trailingBlankLines,
    );
  }

  /// Decode [text] exactly like [decode], but additionally recognize a leading title page (see
  /// `FountainParser`'s own title-page pre-pass) and prepend one node per
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
        : const FountainTitlePageWriter().apply(
            source: text,
            existingRange: titlePage.sourceRange,
            entries: const [],
          );

    final titlePageNodes = OcptWysiwygTitlePage.nodesFrom(titlePage);
    final bodyDecoded = decode(bodyText);

    return OcptWysiwygDecodeResult(
      // Element type spelled out rather than inferred, like every other `MutableDocument` built in
      // this class: see [decode] for what a list narrowed to `ParagraphNode` does to `reset()`.
      document: MutableDocument(nodes: <DocumentNode>[...titlePageNodes, ...bodyDecoded.document]),
      mapping: bodyDecoded.mapping,
      trailingBlankLines: bodyDecoded.trailingBlankLines,
      titlePageNodeCount: titlePageNodes.length,
      titlePagePrefixLength: text.length - bodyText.length,
    );
  }

  /// Decode [text] into the nodes a paste would insert, with the full metadata set [decode]
  /// itself gives every node (`blockType`, [ocptBlankLinesBeforeMetadataKey],
  /// [ocptTypeLockedMetadataKey] always false, [ocptHadForcingMarkerMetadataKey]) — unlike
  /// [decode], this never synthesizes an empty node for all-blank input, since there is nothing
  /// useful to paste in that case: the caller sees an empty list instead.
  static List<ParagraphNode> decodeNodesFromFountain(String text) {
    final (nodes, _, _, _) = OcptWysiwygDecoder.decodeLines(_splitLines(text));
    return nodes;
  }

  /// Encode [document] back into Fountain source text, the inverse of [decode]: rejoins each
  /// node's inline attributions into marked-up display text
  /// ([FountainInlineSerializer.write]/[OcptWysiwygInlineRuns.runsFromAttributedText]), then lets
  /// [FountainLineWriter] decide, left to right with the already-fixed earlier lines as context,
  /// whether each node's stored `blockType` needs a forcing marker to (re-)classify correctly,
  /// honoring [ocptHadForcingMarkerMetadataKey] to preserve a marker even when auto-detection alone
  /// would already suffice. [trailingBlankLines] (normally
  /// [OcptWysiwygDecodeResult.trailingBlankLines], carried forward by the caller across a session,
  /// since nothing in this model's node structure tracks it) is appended as that many blank lines
  /// at the very end.
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
  static OcptWysiwygEncodeResult encode(
    Document document, {
    int trailingBlankLines = 0,
    Set<String>? inertNodeIds,
  }) {
    final nodes = document.map((node) => node as ParagraphNode).toList(growable: false);
    final (layout, lineRangeOfNode) = OcptWysiwygComments.layoutOfNodes(nodes);
    final isInertByNode = [
      for (var index = 0; index < nodes.length; index++)
        inertNodeIds?.contains(nodes[index].id) ??
            layout.isInertOfNode(lineRangeOfNode[index].$1, lineRangeOfNode[index].$2),
    ];

    final types = [
      for (final node in nodes)
        OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")),
    ];
    final displayTextByNode = [
      for (var index = 0; index < nodes.length; index++)
        isInertByNode[index]
            ? ""
            : _displayTextForEncode(
                nodes[index],
                types[index],
                layout.boneyardStarsOfNode(lineRangeOfNode[index].$1, lineRangeOfNode[index].$2),
              ),
    ];
    final blankLinesBeforeByNode = [
      for (final node in nodes) OcptWysiwygComments.blankLinesBeforeOf(node),
    ];

    // Dialogue/parenthetical have no forcing marker at all (`FountainLineWriter` always emits
    // their text verbatim): their classification depends entirely on the immediately preceding
    // *type* being a dialogue-group member, which a real blank line in between would break (the
    // preceding type would read as blank, not character/parenthetical/dialogue). A character cue
    // is not included here: unlike dialogue/parenthetical, it normally needs to be preceded by a
    // blank line (or the very start of the document) to auto-detect at all, so a real blank line
    // immediately before one (for example between two separate dialogue exchanges that both
    // happen to feature the same character, as in `MARY (O.S.)` / `STEVE` / `STEVE` / `MARY^` in
    // kitchen_sink.fountain) must be preserved, not zeroed.
    //
    // An inert node is read the way the parser reads it: a blanked-out line, which keeps a
    // dialogue group open when it directly follows a member and is blank otherwise.
    final effectiveTypes = List<FountainLineType>.of(types);
    // What the parser's classifier reads of the first line of a node: the layout's blanked-out
    // line for an inert node, the first line of the text about to be written for a live one.
    String textSeenBy(int index) => isInertByNode[index]
        ? layout.classificationLines[lineRangeOfNode[index].$1]
        : _firstLineOf(displayTextByNode[index]);
    String? nextTextSeenAfter(int index) {
      if (index + 1 >= nodes.length) {
        return trailingBlankLines > 0 ? "" : null;
      }
      return blankLinesBeforeByNode[index + 1] > 0 ? "" : textSeenBy(index + 1);
    }

    for (var index = 0; index < nodes.length; index++) {
      final previousType = blankLinesBeforeByNode[index] > 0
          ? FountainLineType.blank
          : (index == 0 ? null : effectiveTypes[index - 1]);
      if (isInertByNode[index]) {
        // An inert node is read as the parser reads its lines: each one classified in context,
        // the commented spans blanked out and nothing more, the type of the node being the one
        // its last line leaves.
        final (start, count) = lineRangeOfNode[index];
        var type = previousType;
        for (var line = start; line < start + count; line++) {
          type = _classifier.classifyLine(
            layout.classificationLines[line],
            previousType: type,
            nextRawLine: line + 1 < start + count
                ? layout.classificationLines[line + 1]
                : nextTextSeenAfter(index),
          );
        }
        effectiveTypes[index] = type!;
        continue;
      }
      final continuesDialogueGroup =
          (types[index] == FountainLineType.dialogue ||
              types[index] == FountainLineType.parenthetical) &&
          index > 0 &&
          _isDialogueGroupMember(effectiveTypes[index - 1]);
      if (continuesDialogueGroup) {
        blankLinesBeforeByNode[index] = 0;
      }
    }

    final outputLines = <String>[];
    for (var index = 0; index < nodes.length; index++) {
      for (var blank = 0; blank < blankLinesBeforeByNode[index]; blank++) {
        outputLines.add("");
      }

      // An inert node is written as it is: no marker, no escaping, no reclassification.
      if (isInertByNode[index]) {
        outputLines.add(
          _inertLineOf(
            nodes[index],
            layout.boneyardStarsOfNode(lineRangeOfNode[index].$1, lineRangeOfNode[index].$2),
          ),
        );
        continue;
      }

      // `FountainLineType.pageBreak`/`centeredText` never derive their written line from a
      // forcing-marker decision (see the class doc comment's empty-node rule), so an empty
      // display text never risks stranding a marker there; every other type does, and always
      // serializes an empty node as a plain empty line instead.
      final displayText = displayTextByNode[index];
      final type = types[index];
      if (displayText.isEmpty &&
          type != FountainLineType.pageBreak &&
          type != FountainLineType.centeredText) {
        outputLines.add("");
        continue;
      }

      // A node covering several lines is written in two parts: its first line, through the writer,
      // which reads the line after it as the next line, and the rest as it is. The classifier of
      // the parser reads the whole lines of a note running over several lines, not its folded
      // text, so only the first line has anything to be decided.
      final (firstLine, restLines) = _splitFirstLine(displayText);
      final (start, _) = lineRangeOfNode[index];
      final nextRawLine = restLines == null
          ? nextTextSeenAfter(index)
          : layout.classificationLines[start + 1];
      final previousType = blankLinesBeforeByNode[index] > 0
          ? FountainLineType.blank
          : (index == 0 ? null : effectiveTypes[index - 1]);

      final classifiedText = _classifiedTextOf(
        nodes[index],
        firstLine,
        layout.classificationLines[start],
      );

      // A page break and a centered text have no plain form, so the writer always wraps them. A
      // node holding the whole source line of one (see [_stripDisplayText]) is written as it is.
      if ((type == FountainLineType.pageBreak || type == FountainLineType.centeredText) &&
          _classifier.classifyLine(
                classifiedText ?? firstLine,
                previousType: previousType,
                nextRawLine: nextRawLine,
              ) ==
              type) {
        outputLines.add(displayText);
        continue;
      }

      final writtenFirstLine = _lineWriter.writeLine(
        text: firstLine,
        type: types[index],
        hadForcingMarker: _readHadForcingMarker(nodes[index]),
        previousType: previousType,
        nextRawLine: nextRawLine,
        classifiedText: classifiedText,
        sectionLevel: _readSectionLevel(nodes[index]),
      );
      outputLines.add(restLines == null ? writtenFirstLine : "$writtenFirstLine\n$restLines");
    }

    for (var blank = 0; blank < trailingBlankLines; blank++) {
      outputLines.add("");
    }

    final text = outputLines.join("\n");
    return OcptWysiwygEncodeResult(
      text: text,
      mapping: OcptWysiwygLineMapping.build(
        sourceText: text,
        blankLinesBeforeByNode: blankLinesBeforeByNode,
        trailingBlankLines: trailingBlankLines,
        lineCountByNode: [for (final node in nodes) OcptWysiwygComments.lineCountOf(node)],
      ),
    );
  }

  /// Encode [document] exactly like [encode], but additionally recognize [document]'s leading
  /// title-page field nodes ([isTitlePageNode]) and splice them in as a real Fountain title page
  /// ahead of the body text [encode] itself produces for the remaining nodes, through
  /// [FountainTitlePageWriter.apply] — never a hand-written `Key: value` line, so this and
  /// `OcptEditorTitlePageDialog`'s `⋮ ▸ Title page…` flow stay two front-ends over the one writer.
  /// A field with only empty lines (the common case for most of the six: see
  /// [decodeWithTitlePage]'s synthesis rule) is dropped entirely, exactly like
  /// [FountainTitlePageWriter.apply] drops a title page with no entries at all.
  ///
  /// See [OcptWysiwygEncodeResult.titlePageNodeCount]/[OcptWysiwygEncodeResult
  /// .titlePagePrefixLength]'s own doc comments for what a caller needs them for.
  static OcptWysiwygEncodeResult encodeWithTitlePage(
    Document document, {
    int trailingBlankLines = 0,
  }) {
    final allNodes = document.map((node) => node as ParagraphNode).toList(growable: false);
    final titlePageNodes = <ParagraphNode>[];
    final bodyNodes = <ParagraphNode>[];
    for (final node in allNodes) {
      (isTitlePageNode(node) ? titlePageNodes : bodyNodes).add(node);
    }

    // `List<DocumentNode>.of`, `bodyNodes` being a `List<ParagraphNode>`: see [decode].
    final bodyEncoded = encode(
      MutableDocument(nodes: List<DocumentNode>.of(bodyNodes)),
      trailingBlankLines: trailingBlankLines,
    );
    final titlePageEntries = [
      ...OcptWysiwygTitlePage.entriesFromNodes(titlePageNodes),
      ...OcptWysiwygTitlePage.extraEntriesFromNodes(titlePageNodes),
    ];
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

  /// Tell whether [node] is one of [decodeWithTitlePage]'s synthesized title-page field nodes
  /// ([ocptTitlePageKeyMetadataKey] set) rather than an ordinary body line: every pass in this
  /// class that classifies, forces or uppercases a node's text (none of which has any meaning for
  /// a title-page field) checks this first and skips the node entirely when it's true.
  static bool isTitlePageNode(ParagraphNode node) =>
      node.getMetadataValue(ocptTitlePageKeyMetadataKey) is String;

  /// Encode just the [selection] span of [document] into Fountain source text, for the
  /// clipboard: reuses [encode] on a throwaway document holding only the selected nodes (clipping
  /// the first and last node's text to the selection's own start/end offsets, attributions
  /// preserved), so a copied fragment stays a faithful, independently round-trippable Fountain
  /// excerpt — decodable again by [decodeNodesFromFountain] on paste, or by [decode] if pasted
  /// into another Fountain-aware target. The first node's [ocptBlankLinesBeforeMetadataKey] is
  /// forced to 0 so a copied fragment never starts with leading blank lines; every other node
  /// keeps its own metadata untouched, including its blank-lines-before count, so the spacing
  /// between the copied lines survives.
  static String encodeSelectionToFountain(Document document, DocumentSelection selection) {
    final nodes = OcptWysiwygSelectionClip.clippedNodes(document, selection);
    if (nodes.isEmpty) {
      return "";
    }

    // Element type spelled out: `ParagraphNode.copyWithAddedMetadata` overrides its `TextNode`
    // parent with a covariant `ParagraphNode` return type, so this literal would otherwise infer as
    // a `List<ParagraphNode>` — see [decode] for what that costs.
    final adjustedNodes = <DocumentNode>[
      nodes.first.copyWithAddedMetadata({ocptBlankLinesBeforeMetadataKey: 0}),
      ...nodes.skip(1),
    ];
    // The dual-dialogue suffix belongs to the end of its cue: a cue copied only in part leaves it
    // behind.
    final range = selection.normalize(document);
    final endNode = document.getNodeById(range.end.nodeId);
    final endPosition = range.end.nodePosition;
    if (endNode is ParagraphNode &&
        endPosition is TextNodePosition &&
        endPosition.offset < endNode.text.length) {
      final last = adjustedNodes.length - 1;
      adjustedNodes[last] = adjustedNodes[last].copyWithAddedMetadata({
        ocptDualDialogueMetadataKey: null,
      });
    }
    // The nodes were clipped out of their surroundings: which of them are inert is what the whole
    // document says, not what the fragment alone would.
    // A node clipped down to its notes alone is a line of notes whatever the rest of its line was:
    // it is written as one, with no forcing marker.
    final inertIds = {
      ...inertNodeIds(document),
      for (final node in adjustedNodes.whereType<ParagraphNode>())
        if (OcptWysiwygInlineRuns.holdsOnlyNotes(node.text)) node.id,
    };
    return encode(MutableDocument(nodes: adjustedNodes), inertNodeIds: inertIds).text;
  }

  /// Compute the requests needed to bring every unlocked, non-empty node's `blockType` metadata
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
  static List<EditRequest> reclassifyRequests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
  }) {
    // Title-page field nodes are filtered out before building the virtual line list below (not
    // just skipped when generating a request for them): their text has no place in the body's own
    // classification context (a real body node's auto-detection must never depend on what a title
    // field happens to hold).
    final (nodes, layout, lineRangeOfNode) = OcptWysiwygComments.resolve(document, documentLayout);
    final types = [
      for (final node in nodes)
        OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")),
    ];

    // Reconstruct the virtual line list every node's context depends on: blank runs are real
    // nodes' metadata, not nodes, so they must be reinserted before classifying, and the
    // commented spans are blanked out the way the parser does before it classifies, so a line
    // after a boneyard is read the same here and there.
    final virtualLines = List<String>.of(layout.classificationLines);
    for (var index = 0; index < nodes.length; index++) {
      final (start, count) = lineRangeOfNode[index];
      if (layout.isInertOfNode(start, count)) {
        continue;
      }
      virtualLines[start] = _virtualLineForNode(
        nodes[index],
        types[index],
        layout.classificationLines[start],
      );
    }
    final classifiedTypes = _classifier.classify(virtualLines);

    final requests = <EditRequest>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];

      final (start, count) = lineRangeOfNode[index];
      if (node.text.toPlainText().trim().isEmpty || layout.isInertOfNode(start, count)) {
        continue;
      }

      if (_readTypeLocked(node)) {
        continue;
      }

      final expectedAttribution = OcptFountainLineAttributions.attributionOf(
        classifiedTypes[layout.firstClassifiedLineOfNode(start, count)],
      );
      final currentBlockType = node.getMetadataValue("blockType");
      if (currentBlockType is NamedAttribution &&
          currentBlockType.name == expectedAttribution.name) {
        continue;
      }

      requests.add(
        ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: expectedAttribution),
      );
    }

    return requests;
  }

  /// Compute the requests needed to absorb a trailing `#N#` tag typed live into a scene heading
  /// node's text: strips it from the node's text (an [OcptReplaceNodeTextRequest]) and stores the
  /// captured number as [ocptSceneNumberMetadataKey] metadata (an [OcptChangeNodeMetadataRequest]),
  /// so the tag never lingers as literal, visible text in the styled view.
  ///
  /// Only scene-heading nodes are considered. Run this pass, and execute its requests, *before*
  /// [reclassifyRequests]/[uppercaseRequests] are even computed (see the call site in
  /// `OcptStyledScreenplayEditor._syncAfterEdit`): otherwise a request from this pass and one from
  /// [uppercaseRequests], both computed against the same pre-strip text, would each replace the
  /// node's text wholesale, and whichever executes last would silently undo the other.
  static List<EditRequest> sceneNumberRequests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
    Set<String> composingNodeIds = const {},
  }) {
    final requests = <EditRequest>[];
    final inertIds = inertNodeIds(document, documentLayout: documentLayout);

    for (final node in document) {
      if (node is! ParagraphNode ||
          isTitlePageNode(node) ||
          inertIds.contains(node.id) ||
          composingNodeIds.contains(node.id)) {
        continue;
      }

      final type = OcptFountainLineAttributions.typeOfAttributionValue(
        node.getMetadataValue("blockType"),
      );
      if (type != FountainLineType.sceneHeading) {
        continue;
      }

      final plainText = node.text.toPlainText();
      final match = OcptWysiwygMarkers.sceneNumberPattern.firstMatch(plainText);
      if (match == null) {
        continue;
      }

      final strippedLength = plainText.substring(0, match.start).trimRight().length;
      requests.add(
        OcptReplaceNodeTextRequest(nodeId: node.id, text: node.text.copyText(0, strippedLength)),
      );
      requests.add(
        OcptChangeNodeMetadataRequest(
          nodeId: node.id,
          metadata: {ocptSceneNumberMetadataKey: match.group(1)},
        ),
      );
    }

    return requests;
  }

  /// Compute the requests needed to uppercase the text of every node currently classified as one
  /// of [_uppercasedTypes] whose text isn't already fully uppercase (a character cue forced with
  /// `@` keeps its case), preserving its attribution spans and (since uppercasing is 1:1 for the
  /// app's locales, leaving every character's offset unchanged) the caret position.
  ///
  /// What lies inside a commented span is never touched: an inert node is skipped entirely, and a
  /// note (`[[ ... ]]`) or a boneyard on a live line keeps its text as written.
  static List<EditRequest> uppercaseRequests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
    Set<String> composingNodeIds = const {},
  }) {
    final requests = <EditRequest>[];
    final (nodes, layout, lineRangeOfNode) = OcptWysiwygComments.resolve(document, documentLayout);

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final (start, count) = lineRangeOfNode[index];
      if (layout.isInertOfNode(start, count) || composingNodeIds.contains(node.id)) {
        continue;
      }

      final blockType = OcptFountainLineAttributions.typeOfAttributionValue(
        node.getMetadataValue("blockType"),
      );
      if (!_uppercasedTypes.contains(blockType)) {
        continue;
      }
      if (blockType == FountainLineType.character && _readHadForcingMarker(node)) {
        continue;
      }

      final plainText = node.text.toPlainText();
      final upperText = OcptWysiwygInlineRuns.uppercasedOutside(
        plainText,
        OcptWysiwygComments.nodeRangesOf(node, layout.commentRangesOfNode(start, count)),
      );
      if (upperText == plainText) {
        continue;
      }

      requests.add(
        OcptReplaceNodeTextRequest(
          nodeId: node.id,
          text: OcptWysiwygInlineRuns.uppercased(node.text, upperText),
        ),
      );
    }

    return requests;
  }

  /// Compute the requests bringing the notes of every body node in line with the invariant of the
  /// styled editor, the ones that satisfy it held as placeholders and the others as text (see
  /// [OcptWysiwygNotes.requests]).
  static List<EditRequest> noteRequests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
    Set<String> composingNodeIds = const {},
  }) => OcptWysiwygNotes.requests(
    document,
    documentLayout: documentLayout,
    composingNodeIds: composingNodeIds,
  );

  /// Compute the requests bringing every node's note attribution in sync with its text (see
  /// [OcptWysiwygComments.noteAttributionRequests]).
  static List<EditRequest> noteAttributionRequests(Document document) =>
      OcptWysiwygComments.noteAttributionRequests(document);

  /// Compute the requests bringing every body node's comment attribution in sync with the
  /// commented spans of the document (see [OcptWysiwygComments.commentAttributionRequests]).
  static List<EditRequest> commentAttributionRequests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
  }) => OcptWysiwygComments.commentAttributionRequests(document, documentLayout: documentLayout);

  /// Get the (start, exclusive end) ranges of the notes [node]'s text holds (see
  /// [OcptWysiwygComments.noteRangesOf]).
  static List<(int, int)> noteRangesOf(ParagraphNode node) =>
      OcptWysiwygComments.noteRangesOf(node);

  /// Get the text of [node] the commented spans are looked for in (see
  /// [OcptWysiwygComments.virtualTextOf]).
  static String virtualTextOf(ParagraphNode node) => OcptWysiwygComments.virtualTextOf(node);

  /// Get the ids of the inert nodes of [document] (see [OcptWysiwygComments.inertNodeIds]).
  static Set<String> inertNodeIds(Document document, {OcptWysiwygDocumentLayout? documentLayout}) =>
      OcptWysiwygComments.inertNodeIds(document, documentLayout: documentLayout);

  /// Lay out the body of [document] as lines of plain text, to hand to the passes of one settle
  /// (see [OcptWysiwygComments.layoutOf]).
  static OcptWysiwygDocumentLayout layoutOf(Document document) =>
      OcptWysiwygComments.layoutOf(document);

  /// Split [text] into its source lines, normalizing `\r\n`/`\r` line endings to `\n` first (the
  /// same normalization `FountainParser.parse` applies), so folded blank-line counts and the
  /// resulting [OcptWysiwygLineMapping] agree with the rest of the editor.
  static List<String> _splitLines(String text) =>
      text.replaceAll("\r\n", "\n").replaceAll("\r", "\n").split("\n");

  /// Get [displayText], the first line of the text [encode] writes for [node], as the parser's
  /// classifier reads it: its boneyards and standalone notes blanked out, [classificationLine]
  /// being the node's first line so blanked. Null when nothing differs, or when [displayText] is
  /// not the first line of the node's plain text (with at most a scene number after it): emphasis
  /// markers shift every offset.
  static String? _classifiedTextOf(
    ParagraphNode node,
    String displayText,
    String classificationLine,
  ) {
    final plainText = _firstLineOf(OcptWysiwygComments.plainLineOf(node, node.text.toPlainText()));
    if (!displayText.startsWith(plainText) || classificationLine == plainText) {
      return null;
    }
    return classificationLine + displayText.substring(plainText.length);
  }

  /// Get the first line of [text].
  static String _firstLineOf(String text) {
    final newline = text.indexOf("\n");
    return newline < 0 ? text : text.substring(0, newline);
  }

  /// Split [text] into its first line and the lines after it, the latter null when [text] has only
  /// one.
  static (String, String?) _splitFirstLine(String text) {
    final newline = text.indexOf("\n");
    return newline < 0 ? (text, null) : (text.substring(0, newline), text.substring(newline + 1));
  }

  /// Get the source line [encode] writes for the inert [node], byte for byte: its text, plus what
  /// a node decoded as a live line would have been written with (a scene number, a forcing marker)
  /// when it only became inert afterwards.
  static String _inertLineOf(ParagraphNode node, List<int> boneyardStars) {
    final type = OcptFountainLineAttributions.typeOfAttributionValue(
      node.getMetadataValue("blockType"),
    );
    var line = _serialize(node, boneyardStars);
    final sceneNumber = _readSceneNumber(node);
    if (type == FountainLineType.sceneHeading && sceneNumber != null) {
      line = "$line #$sceneNumber#";
    }
    final dualSuffix = OcptWysiwygDualDialogue.suffixOf(node);
    if (type == FountainLineType.character && dualSuffix != null && line.isNotEmpty) {
      line = "$line$dualSuffix";
    }
    if (!_readHadForcingMarker(node) || type == FountainLineType.blank) {
      return line;
    }
    return _lineWriter.writeLine(
      text: line,
      type: type,
      hadForcingMarker: true,
      previousType: null,
      nextRawLine: null,
      sectionLevel: _readSectionLevel(node),
    );
  }

  /// Tell whether [type] is a dialogue-block element that keeps a dialogue group open (see
  /// [FountainLineClassifier]'s own equivalent private rule), used by [encode] to force
  /// [ocptBlankLinesBeforeMetadataKey] to 0 between two directly-adjacent members.
  static bool _isDialogueGroupMember(FountainLineType type) =>
      type == FountainLineType.character ||
      type == FountainLineType.parenthetical ||
      type == FountainLineType.dialogue;

  /// Read a node's [ocptHadForcingMarkerMetadataKey] metadata, defaulting to false.
  static bool _readHadForcingMarker(ParagraphNode node) =>
      node.getMetadataValue(ocptHadForcingMarkerMetadataKey) == true;

  /// Read a node's [ocptSectionLevelMetadataKey] metadata, clamped to 1-6, defaulting to 1.
  static int _readSectionLevel(ParagraphNode node) {
    final level = node.getMetadataValue(ocptSectionLevelMetadataKey);
    return level is int ? level.clamp(1, 6) : 1;
  }

  /// Serialize [node]'s styled text into marked-up source, through the one serializer.
  static String _serialize(ParagraphNode node, List<int> boneyardStars) => _inlineSerializer.write(
    OcptWysiwygInlineRuns.runsFromAttributedText(node.text),
    literalStars: boneyardStars.toSet(),
  );

  /// Read a node's [ocptSceneNumberMetadataKey] metadata, or null if it isn't set.
  static String? _readSceneNumber(ParagraphNode node) {
    final value = node.getMetadataValue(ocptSceneNumberMetadataKey);
    return value is String ? value : null;
  }

  /// Get the text [encode] hands to [_lineWriter] for [node]: its inline-serialized display text,
  /// with a scene heading's [ocptSceneNumberMetadataKey] tag re-appended when set. Never appends
  /// to an empty base text, so an emptied heading still serializes through the empty-node rule
  /// (a plain blank line) rather than stranding a lone `#N#` tag.
  static String _displayTextForEncode(
    ParagraphNode node,
    FountainLineType type,
    List<int> boneyardStars,
  ) {
    final base = _serialize(node, boneyardStars);
    if (type == FountainLineType.character && base.isNotEmpty) {
      return "$base${OcptWysiwygDualDialogue.suffixOf(node) ?? ""}";
    }
    if (type != FountainLineType.sceneHeading || base.isEmpty) {
      return base;
    }

    final sceneNumber = _readSceneNumber(node);
    return sceneNumber == null ? base : "$base #$sceneNumber#";
  }

  /// Read a node's [ocptTypeLockedMetadataKey] metadata, defaulting to false.
  static bool _readTypeLocked(ParagraphNode node) =>
      node.getMetadataValue(ocptTypeLockedMetadataKey) == true;

  /// Tell whether [node]'s stored `blockType` is pinned by the user rather than up for
  /// auto-detection, per [reclassifyRequests]'s doc comment: either a manual dropdown/Tab choice
  /// ([ocptTypeLockedMetadataKey]) or a source line that carried an explicit forcing marker
  /// ([ocptHadForcingMarkerMetadataKey]) — the *serialized* form of that very same "the user fixed
  /// this type on purpose" intent, already honoured by [encode] and, until this method existed,
  /// silently ignored by [reclassifyRequests].
  static bool _isPinnedNode(ParagraphNode node) =>
      _readTypeLocked(node) || _readHadForcingMarker(node);

  /// Get the virtual source line [reclassifyRequests] feeds the classifier for [node], currently
  /// stored as [type], from its [displayText] (its text, its commented spans blanked out). A pinned
  /// node (see [_isPinnedNode]) gets its marker re-emitted through
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
  static String _virtualLineForNode(ParagraphNode node, FountainLineType type, String displayText) {
    if (displayText.isEmpty || !_isPinnedNode(node)) {
      return displayText;
    }

    return _lineWriter.writeLine(
      text: displayText,
      type: type,
      hadForcingMarker: true,
      previousType: null,
      nextRawLine: null,
      sectionLevel: _readSectionLevel(node),
    );
  }
}
