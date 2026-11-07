// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:super_editor/super_editor.dart';

/// The `ParagraphNode` metadata key holding which title-page field a node represents (one of
/// [ocptTitlePageFieldKeys]), or absent for an ordinary body line.
///
/// Only ever set by `OcptWysiwygCodec.decodeWithTitlePage` (and the keyboard action that keeps a
/// title-page field's own Enter gesture continuing the same field, `_splitTitlePageField` in
/// `ocpt_fountain_keyboard_actions.dart`): none of the ordinary Fountain line machinery this class
/// documents (auto-detection, forcing markers, uppercasing, scene numbers…) ever applies to a node
/// carrying it, which is what `OcptWysiwygCodec.isTitlePageNode` lets every one of those passes
/// check for and skip.
const String ocptTitlePageKeyMetadataKey = "ocptTitlePageKey";

/// The `blockType` attribution shared by every title-page field node, regardless of which field it
/// represents ([ocptTitlePageKeyMetadataKey] carries that distinction instead): a title-page field
/// is never classified, never forced, never uppercased, so it needs no per-field attribution the
/// way every [FountainLineType] gets its own in `OcptFountainLineAttributions` — only a stylesheet
/// selector to opt into `OcptFountainEditorStylesheet`'s own per-field positioning.
const NamedAttribution ocptTitlePageFieldAttribution = NamedAttribution("fountainTitlePageField");

/// The six canonical title-page field keys `OcptWysiwygCodec.decodeWithTitlePage` always
/// synthesizes exactly one node for (more if a field spans several source lines), in the fixed
/// order they are written to the source and stacked top-to-bottom in the styled editor — matching
/// the order `OcptEditorTitlePageDialog`'s `⋮ ▸ Title page…` fields already appear in
/// (`editor_bloc.dart`'s `_titlePageEntriesFrom`), so editing the same screenplay through either
/// front-end never reorders the block for no reason.
const List<String> ocptTitlePageFieldKeys = [
  "Title",
  "Credit",
  "Author",
  "Draft date",
  "Contact",
  "Source",
];

/// The title-page half of `OcptWysiwygCodec`: builds the title-page field nodes from a parsed
/// [FountainTitlePage] and folds live nodes back into the entries the title-page writer expects.
final class OcptWysiwygTitlePage {
  /// A placeholder source range for a title-page entry synthesized from live node text rather than
  /// parsed from source: [FountainTitlePageWriter.apply] only ever reads an entry's key and values,
  /// never its source range (see `editor_bloc.dart`'s own equivalent placeholder), so standing in
  /// without a real one is safe.
  static const _placeholderEntryRange = FountainSourceRange(
    startLine: 0,
    endLine: 0,
    startOffset: 0,
    endOffset: 0,
  );

  /// Private constructor: this class only exposes static members.
  const OcptWysiwygTitlePage._();

  /// Get the title page entry for [key] (`Author` also matching a source written as `Authors`, per
  /// `FountainTitlePage.authors`'s own fallback), or null when [titlePage] is null or has no such
  /// entry.
  static FountainTitlePageEntry? entryFor(FountainTitlePage? titlePage, String key) {
    if (titlePage == null) {
      return null;
    }
    return key == "Author"
        ? (titlePage.entry("Author") ?? titlePage.entry("Authors"))
        : titlePage.entry(key);
  }

  /// Build the title-page field nodes `decodeWithTitlePage` prepends to the body: one node per
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
  static List<ParagraphNode> nodesFrom(FountainTitlePage? titlePage) {
    final nodes = <ParagraphNode>[];
    for (final key in ocptTitlePageFieldKeys) {
      final entry = entryFor(titlePage, key);
      final values = entry == null || entry.values.isEmpty ? const [""] : entry.values;
      for (final value in values) {
        nodes.add(
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(value),
            metadata: {
              "blockType": ocptTitlePageFieldAttribution,
              ocptTitlePageKeyMetadataKey: key,
            },
          ),
        );
      }
    }
    return nodes;
  }

  /// Get the inverse of [nodesFrom]: groups [titlePageNodes] (already in the fixed
  /// [ocptTitlePageFieldKeys] order, one run of consecutive nodes per field, by construction) back
  /// into [FountainTitlePageEntry] values, dropping a field whose every line is empty (the common
  /// case for most fields most of the time) so [FountainTitlePageWriter.apply] never writes a
  /// stray `Key:` line with nothing after it.
  static List<FountainTitlePageEntry> entriesFromNodes(List<ParagraphNode> titlePageNodes) {
    final entries = <FountainTitlePageEntry>[];
    String? currentKey;
    var currentValues = <String>[];

    void flush() {
      final key = currentKey;
      if (key != null) {
        final nonEmptyValues = currentValues
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false);
        if (nonEmptyValues.isNotEmpty) {
          entries.add(
            FountainTitlePageEntry(
              key: key,
              values: nonEmptyValues,
              sourceRange: _placeholderEntryRange,
            ),
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
}
