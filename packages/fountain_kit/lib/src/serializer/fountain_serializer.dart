// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';

/// Writes a [FountainDocument] back out as canonical Fountain source text.
///
/// The serializer does not aim to reproduce a parsed document's original
/// source text byte-for-byte (whitespace between blocks, marker case,
/// exact scene number placement etc. are all re-normalized); it aims to
/// reproduce text that a parser parses back into a [FountainDocument] equal
/// to the one it was given. That round-trip guarantee, not textual
/// identity, is what this package's tests rely on.
class FountainSerializer {
  /// Creates a [FountainSerializer].
  const FountainSerializer();

  /// Renders [document] as Fountain source text.
  String write(FountainDocument document) {
    final parts = <String>[];
    final titlePage = document.titlePage;
    if (titlePage != null) {
      parts.add(_writeTitlePage(titlePage));
    }
    parts.addAll(document.blocks.map(_writeBlock));
    return parts.join('\n\n');
  }

  /// Renders a title page as `key: value` lines, one block of text.
  String _writeTitlePage(FountainTitlePage titlePage) =>
      titlePage.entries.map(_writeTitleEntry).join('\n');

  /// Renders a single title page entry.
  String _writeTitleEntry(FountainTitlePageEntry entry) {
    if (entry.values.length == 1) {
      return '${entry.key}: ${entry.values.single}';
    }
    final continuationLines = entry.values
        .map((value) => '    $value')
        .join('\n');
    return '${entry.key}:\n$continuationLines';
  }

  /// Renders a single top-level block.
  String _writeBlock(FountainBlock block) => switch (block) {
    FountainSceneHeading() => block.rawText,
    FountainActionBlock() => _writeAction(block),
    FountainCharacter() => _writeCharacter(block),
    FountainParenthetical() => '(${block.text})',
    FountainDialogueLine() => _writeDialogueLine(block),
    FountainDialogueGroup() => _writeDialogueGroup(block),
    FountainTransition() => block.forced ? '>${block.text}' : block.text,
    FountainLyrics() => block.lines.map((line) => '~$line').join('\n'),
    FountainCenteredText() => '> ${block.text} <',
    FountainSection() => '${'#' * block.level} ${block.text}',
    FountainSynopsis() => '= ${block.text}',
    FountainNoteBlock() => '[[${block.text}]]',
    FountainBoneyard() => '/*${block.text}*/',
    FountainPageBreak() => '===',
  };

  /// Renders a [FountainActionBlock], re-adding its forcing `!` marker if
  /// [FountainActionBlock.forced] is set.
  String _writeAction(FountainActionBlock block) {
    final lines = List<String>.of(block.lines);
    if (block.forced && lines.isNotEmpty) {
      lines[0] = '!${lines[0]}';
    }
    return lines.join('\n');
  }

  /// Renders a [FountainCharacter] cue. A name that is not already all
  /// uppercase is forced with a leading `@` so it is recognized on
  /// re-parse regardless of case.
  String _writeCharacter(FountainCharacter character) {
    final needsForcing = character.name != character.name.toUpperCase();
    final buffer = StringBuffer();
    if (needsForcing) {
      buffer.write('@');
    }
    buffer.write(character.name);
    final extension = character.extension;
    if (extension != null) {
      buffer.write(' ($extension)');
    }
    if (character.isDualDialogue) {
      buffer.write('^');
    }
    return buffer.toString();
  }

  /// Renders a [FountainDialogueLine], substituting two spaces for a
  /// blank line so the "preserved blank dialogue line" round-trips back
  /// into an empty [FountainDialogueLine.text] rather than ending the
  /// dialogue block.
  String _writeDialogueLine(FountainDialogueLine line) =>
      line.text.trim().isEmpty ? '  ' : line.text;

  /// Renders a [FountainDialogueGroup]: its character cue followed by its
  /// parentheticals and dialogue lines, one per source line.
  String _writeDialogueGroup(FountainDialogueGroup group) {
    final lines = [
      _writeCharacter(group.character),
      ...group.children.map(_writeBlock),
    ];
    return lines.join('\n');
  }
}
