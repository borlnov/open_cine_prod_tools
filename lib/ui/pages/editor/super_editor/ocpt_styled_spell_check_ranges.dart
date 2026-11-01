// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_spell_checked_lines.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:spell_kit/spell_kit.dart';
import 'package:super_editor/super_editor.dart';

/// The styled mode's own half of the spell-check underline (`docs/architecture/screenplay.md`):
/// owns super_editor's `SpellingAndGrammarStyler`, the misspelled ranges last applied to it, and
/// the rules deciding which node texts are worth checking.
///
/// The document is resolved through a callback at call time, since the styled editor replaces it
/// whenever its text is rebuilt from outside.
final class OcptStyledSpellCheckRanges {
  /// The styler painting the squiggles: `text.dart` already turns a component's
  /// `TextComponentViewModel.spellingErrors` into the squiggle super_editor paints, so no styler of
  /// our own is needed here. The underline colour is [ocptEditorSpellCheckErrorColor], the exact
  /// colour the raw mode's own controller underlines with, so both surfaces read as the same
  /// feature. Never rebuilt, since `addErrors`/`clearErrorsForNode`/`clearAllErrors` calls must
  /// survive across a build.
  final SpellingAndGrammarStyler styler;

  /// Resolves the document the ranges address.
  final MutableDocument Function() _documentOf;

  /// The misspelled ranges [update] last applied to [styler], keyed by node id and remembered here
  /// too so a right-click can tell whether it landed inside one — [SpellingAndGrammarStyler]
  /// itself exposes no getter to ask that of.
  Map<String, List<SpellRange>> _lastRangesByNodeId;

  /// The document the ranges address.
  MutableDocument get _document => _documentOf();

  /// Creates an [OcptStyledSpellCheckRanges].
  OcptStyledSpellCheckRanges({required MutableDocument Function() documentOf})
    : styler = SpellingAndGrammarStyler(
        spellingErrorUnderlineStyle: const SquiggleUnderlineStyle(
          color: ocptEditorSpellCheckErrorColor,
        ),
      ),
      _lastRangesByNodeId = const {},
      _documentOf = documentOf;

  /// Every checkable node text currently in [_document]: a [ParagraphNode] whose classified line
  /// type [ocptIsSpellCheckedLineType] accepts, and never a title-page field node
  /// ([OcptWysiwygCodec.isTitlePageNode]) — the prose-only rule of
  /// `docs/architecture/screenplay.md`, applied here in terms of the
  /// same node metadata `_sceneNumbersFromMetadata`/`_reportReadStateToController` already read,
  /// and its title-page exclusion (a title is invented on purpose, and the six fields
  /// only exist under page simulation, so underlining them would make squiggles appear and
  /// disappear with a display toggle).
  ///
  /// Empty while `OcptStyledScreenplayEditor.isSpellCheckVisible` is off — nothing is ever reported
  /// to check with the switch off — and reports the node's
  /// **display** text (`node.text.toPlainText()`), never the Fountain source: that is what
  /// `SpellingAndGrammarStyler` addresses.
  Map<String, String> checkableTexts({required bool isVisible}) {
    if (!isVisible) {
      return const {};
    }

    final texts = <String, String>{};
    for (final node in _document) {
      if (node is! ParagraphNode || OcptWysiwygCodec.isTitlePageNode(node)) {
        continue;
      }
      final type = OcptFountainLineAttributions.typeOfAttributionValue(
        node.getMetadataValue("blockType"),
      );
      if (!ocptIsSpellCheckedLineType(type)) {
        continue;
      }
      texts[node.id] = node.text.toPlainText();
    }
    return texts;
  }

  /// Applies [rangesByNodeId] — the bloc's own answer, keyed by node id — to
  /// [styler], replacing whatever it held before: every node this widget could
  /// conceivably report is first cleared (`clearAllErrors`), then a fresh set of `TextError`s is
  /// added only for a node id [rangesByNodeId] actually names.
  ///
  /// Two guards `docs/architecture/screenplay.md` is explicit about, applied to every range
  /// before it becomes a
  /// `TextError`: a node id the document no longer holds (a full rebuild since the ranges were
  /// computed — an edit elsewhere, an import, a version restore, a page-simulation toggle) is
  /// ignored outright, and a range that no longer fits that node's own *current* text length is
  /// dropped rather than handed to `TextError.spelling`, which would otherwise build a `TextRange`
  /// past the end of the text it addresses.
  ///
  /// Called both by `OcptStyledEditorController.attach` (a raw → styled mode switch while ranges
  /// are already known) and, reactively, whenever `editor_page.dart` pushes a fresh
  /// `OcptEditorState.styledSpellCheckRanges` down — neither call happens from inside
  /// `_onDocumentChanged`'s own document-change listener, so this never needs the post-frame
  /// deferral `_onDocumentChanged`'s own search recompute does (see that method's long comment):
  /// the crash it guards against is specific to `markDirty()` firing synchronously inside
  /// `Editor.execute()`'s still-open transaction, which is not where this method is ever reached
  /// from.
  void update(Map<String, List<SpellRange>> rangesByNodeId) {
    _lastRangesByNodeId = rangesByNodeId;
    styler.clearAllErrors();

    for (final entry in rangesByNodeId.entries) {
      final node = _document.getNodeById(entry.key);
      if (node is! ParagraphNode) {
        continue;
      }

      final textLength = node.text.toPlainText().length;
      final errors = <TextError>{
        for (final range in entry.value)
          if (range.end <= textLength)
            TextError.spelling(
              nodeId: entry.key,
              range: TextRange(start: range.start, end: range.end),
              value: node.text.toPlainText().substring(range.start, range.end),
            ),
      };
      if (errors.isNotEmpty) {
        styler.addErrors(entry.key, errors);
      }
    }
  }

  /// The misspelled range and word [position] falls inside, according to
  /// [_lastRangesByNodeId], or null when it falls inside none of them — no misspelling
  /// under the tap, or spell-checking is off altogether (in which case that map is empty).
  ///
  /// Checked against the node's own **current** [ParagraphNode.text], not the text the range was
  /// computed against: a range answered by one isolate round trip is already the most exposed
  /// spell-check data in this widget (`docs/architecture/screenplay.md` says why), so a range that
  /// no longer fits the node's current length is treated as no match rather
  /// than read out of bounds.
  ({String nodeId, SpellRange range, String word})? misspellingAt(DocumentPosition position) {
    final ranges = _lastRangesByNodeId[position.nodeId];
    if (ranges == null || ranges.isEmpty) {
      return null;
    }

    final nodePosition = position.nodePosition;
    if (nodePosition is! TextNodePosition) {
      return null;
    }

    final node = _document.getNodeById(position.nodeId);
    if (node is! ParagraphNode) {
      return null;
    }

    final text = node.text.toPlainText();
    final offset = nodePosition.offset;

    for (final range in ranges) {
      if (range.end > text.length) {
        continue;
      }
      if (offset >= range.start && offset <= range.end) {
        return (
          nodeId: position.nodeId,
          range: range,
          word: text.substring(range.start, range.end),
        );
      }
    }
    return null;
  }
}
