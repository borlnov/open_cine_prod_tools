// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:script_import_kit/src/emitter/script_line.dart';
import 'package:script_import_kit/src/emitter/script_title_page.dart';

/// Renders the typed lines a reader produced as Fountain source text.
///
/// This is the one place in the package that knows the Fountain syntax, and
/// it knows it only through `fountain_kit`: [FountainInlineSerializer] for
/// the emphasis markup (the only code that knows how to escape a `*` that
/// was in the source text itself), [FountainLineWriter] for each line's
/// forcing marker, [FountainTitlePageWriter] for the title page block. A
/// reader therefore never writes one character of Fountain by hand, and
/// adding a second reader adds no syntax rule at all.
///
/// The layout rules it applies are the whole of what it decides by itself:
///
/// - a blank line separates two blocks, so that a scene heading, a
///   transition and a character cue can auto-detect (each of those rules
///   demands a blank line before, and sometimes after);
/// - the inside of a dialogue block is never broken by one: a
///   parenthetical or a dialogue line always stays glued to the cue it
///   belongs to, which is the only thing that makes it read as dialogue
///   rather than as action;
/// - a line the source split off the one before it
///   ([ScriptLine.continuesBlock]) stays in the same block;
/// - a line with no text at all is dropped: blank source lines are how
///   blocks are separated here, never content of their own;
/// - the very first line of a screenplay that has no title page is forced
///   whenever it would otherwise open one — see [_looksLikeTitlePageKey].
///
/// Every line then goes through [FountainLineWriter.writeLine] with the
/// type of the line already written before it and the raw text of the one
/// about to be written after it — the same context
/// [FountainLineClassifier.classifyLine] reads — which is what guarantees
/// that re-parsing the produced text yields the very types the reader
/// meant, rather than an all-caps line of dialogue quietly becoming a
/// character cue.
class ScriptFountainEmitter {
  /// Creates a [ScriptFountainEmitter].
  const ScriptFountainEmitter();

  static const FountainInlineSerializer _inlineSerializer =
      FountainInlineSerializer();

  static const FountainLineWriter _lineWriter = FountainLineWriter();

  static const FountainTitlePageWriter _titlePageWriter =
      FountainTitlePageWriter();

  /// Matches a line a Fountain parser would read as the first key of a
  /// title page, mirroring `FountainParser`'s own rule.
  ///
  /// It is restated here rather than imported because the parser keeps it
  /// to itself, and the emitter cannot do without it: the rule only looks
  /// at the document's very first line, so an imported screenplay that
  /// carries no title page and opens on `FADE IN:` — as a great many do —
  /// would have that line swallowed as an empty title page entry and lost.
  static final RegExp _titlePageKey = RegExp('^([A-Za-z][A-Za-z0-9 ]*):');

  /// Renders [lines], under [titlePage], as one Fountain source string.
  ///
  /// The result ends with a newline whenever it holds anything at all, the
  /// way a `.fountain` file on disk does.
  String write({
    required List<ScriptLine> lines,
    ScriptTitlePage titlePage = const ScriptTitlePage(),
  }) {
    final kept = [
      for (final line in lines)
        if (line.plainText.trim().isNotEmpty) line,
    ];

    final rawTexts = [for (final line in kept) _rawTextOf(line)];
    final blankLinesBefore = _blankLinesBefore(kept);

    final entries = titlePage.toEntries();

    final outputLines = <String>[];
    for (var index = 0; index < kept.length; index++) {
      if (blankLinesBefore[index] > 0) {
        outputLines.add('');
      }

      final hasNextLine = index + 1 < kept.length;
      final nextRawLine = hasNextLine
          ? (blankLinesBefore[index + 1] > 0 ? '' : rawTexts[index + 1])
          : null;
      final previousType = blankLinesBefore[index] > 0
          ? FountainLineType.blank
          : (index == 0 ? null : kept[index - 1].type);

      outputLines.add(
        _lineWriter.writeLine(
          text: rawTexts[index],
          type: kept[index].type,
          hadForcingMarker:
              index == 0 &&
              entries.isEmpty &&
              _looksLikeTitlePageKey(rawTexts[index]),
          previousType: previousType,
          nextRawLine: nextRawLine,
        ),
      );
    }

    final body = outputLines.isEmpty ? '' : '${outputLines.join('\n')}\n';
    return _titlePageWriter.apply(
      source: body,
      existingRange: null,
      entries: entries,
    );
  }

  /// The plain text [FountainLineWriter.writeLine] is handed for [line]:
  /// its runs serialized with their emphasis markup, plus the two tags the
  /// writer knows nothing about and the classifier tolerates — a scene
  /// heading's `#N#` number and a cue's dual-dialogue `^`.
  String _rawTextOf(ScriptLine line) {
    final text = _inlineSerializer.write(line.runs);

    final sceneNumber = line.sceneNumber?.trim();
    if (line.type == FountainLineType.sceneHeading &&
        sceneNumber != null &&
        sceneNumber.isNotEmpty) {
      return '$text #$sceneNumber#';
    }

    if (line.type == FountainLineType.character && line.isDualDialogue) {
      return '$text ^';
    }

    return text;
  }

  /// Whether [rawText], written as the first line of a screenplay with no
  /// title page, would be read back as a title page entry rather than as
  /// the line it is.
  ///
  /// The answer only ever matters for the first line, and only when there
  /// is no title page to push it down: a `FADE IN:` or a `CUT TO:` opening
  /// the screenplay is what this catches, and forcing its marker is what
  /// keeps it. The four line types with no forcing marker of their own —
  /// dialogue and a parenthetical, which Fountain gives none, and centered
  /// text and a page break, which are written wrapped and cannot match this
  /// rule anyway — are unaffected: a screenplay whose very first line is a
  /// bare line of dialogue holding a colon cannot be written in Fountain at
  /// all.
  bool _looksLikeTitlePageKey(String rawText) =>
      _titlePageKey.hasMatch(rawText);

  /// How many blank source lines each of [lines] is preceded by: one, to
  /// separate it from the block before, unless it continues that block.
  List<int> _blankLinesBefore(List<ScriptLine> lines) => [
    for (var index = 0; index < lines.length; index++)
      if (index == 0 || _continuesPreviousBlock(lines, index)) 0 else 1,
  ];

  /// Whether the line at [index] belongs to the block the line before it
  /// opened: either because the source itself said so
  /// ([ScriptLine.continuesBlock]), or because it is the inside of a
  /// dialogue block, which a blank line would break apart.
  bool _continuesPreviousBlock(List<ScriptLine> lines, int index) {
    if (lines[index].continuesBlock) {
      return true;
    }

    final type = lines[index].type;
    final isDialogueBody =
        type == FountainLineType.dialogue ||
        type == FountainLineType.parenthetical;
    return isDialogueBody && _isDialogueBlockMember(lines[index - 1].type);
  }

  /// Whether [type] is a line that keeps a dialogue block open for the line
  /// right after it, mirroring `FountainLineClassifier`'s own rule.
  bool _isDialogueBlockMember(FountainLineType type) =>
      type == FountainLineType.character ||
      type == FountainLineType.parenthetical ||
      type == FountainLineType.dialogue;
}
