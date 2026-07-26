// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';

/// The base type of every structural element a Fountain document is made of.
///
/// [FountainBlock] is `sealed`: every concrete element kind is declared in
/// this file, which lets code that switches over a [FountainBlock] be
/// checked exhaustively by the analyzer.
///
/// [sourceRange] deliberately does not participate in equality: two blocks
/// with the same content are equal regardless of where in a source string
/// each was parsed from. This is what lets a round trip through
/// `FountainSerializer.write` (which re-flows text and so changes every
/// offset) be checked by comparing parsed blocks with `==`.
sealed class FountainBlock extends Equatable {
  /// Creates a [FountainBlock].
  const FountainBlock({required this.sourceRange});

  /// The location, in the original source, that this block was parsed from.
  final FountainSourceRange sourceRange;
}

/// A scene heading, for example `INT. KITCHEN - DAY`.
class FountainSceneHeading extends FountainBlock {
  /// Creates a [FountainSceneHeading].
  const FountainSceneHeading({
    required super.sourceRange,
    required this.rawText,
    required this.headingText,
    required this.forcedMarker,
    this.sceneNumber,
  });

  /// The exact, unmodified source line this heading was parsed from,
  /// including any forcing `.` and scene number tag.
  final String rawText;

  /// The normalized heading text: uppercased, with the forcing `.` and the
  /// scene number tag stripped, and outer whitespace trimmed.
  final String headingText;

  /// Whether this heading was forced with a leading `.` rather than being
  /// recognized from an `INT`/`EXT`/`EST`/`INT./EXT`/`I/E` prefix.
  final bool forcedMarker;

  /// The scene number written between `#` characters at the end of the
  /// line (for example `4A` in `INT. HOUSE #4A#`), or `null` if none.
  final String? sceneNumber;

  @override
  List<Object?> get props => [rawText, headingText, forcedMarker, sceneNumber];

  @override
  String toString() => 'FountainSceneHeading($headingText)';
}

/// A paragraph of action/description text.
class FountainActionBlock extends FountainBlock {
  /// Creates a [FountainActionBlock].
  const FountainActionBlock({
    required super.sourceRange,
    required this.lines,
    required this.forced,
  });

  /// The action text, one element per source line, in source order, with
  /// original whitespace/indentation preserved and any leading forcing `!`
  /// already stripped.
  final List<String> lines;

  /// Whether this block was forced with a leading `!`.
  final bool forced;

  @override
  List<Object?> get props => [lines, forced];

  @override
  String toString() => 'FountainActionBlock(${lines.length} lines)';
}

/// A character cue introducing a block of dialogue, for example `SARAH
/// (O.S.)`.
///
/// A [FountainCharacter] never appears on its own in
/// [FountainDocument.blocks]: it is always the [FountainDialogueGroup.character]
/// of the dialogue block it introduces.
class FountainCharacter extends FountainBlock {
  /// Creates a [FountainCharacter].
  const FountainCharacter({
    required super.sourceRange,
    required this.name,
    required this.isDualDialogue,
    this.extension,
  });

  /// The character's name, without its parenthetical extension, forcing `@`
  /// or dual-dialogue `^` marker.
  final String name;

  /// The parenthetical extension written after the name (for example `V.O.`
  /// or `CONT'D`), or `null` if none.
  final String? extension;

  /// Whether this cue was suffixed with `^`, marking the dialogue it
  /// introduces as spoken simultaneously with the dialogue immediately
  /// preceding it.
  final bool isDualDialogue;

  @override
  List<Object?> get props => [name, extension, isDualDialogue];

  @override
  String toString() {
    final suffix = extension == null ? '' : ' ($extension)';
    return 'FountainCharacter($name$suffix)';
  }
}

/// A parenthetical direction inside a block of dialogue, for example
/// `(beat)`.
class FountainParenthetical extends FountainBlock {
  /// Creates a [FountainParenthetical].
  const FountainParenthetical({required super.sourceRange, required this.text});

  /// The parenthetical's text, without its enclosing parentheses.
  final String text;

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'FountainParenthetical($text)';
}

/// A single line of spoken dialogue inside a [FountainDialogueGroup].
class FountainDialogueLine extends FountainBlock {
  /// Creates a [FountainDialogueLine].
  const FountainDialogueLine({required super.sourceRange, required this.text});

  /// The dialogue text. A line that was blank in the source but kept
  /// meaningful by trailing whitespace (see the Fountain spec) is
  /// represented here as an empty string.
  final String text;

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'FountainDialogueLine($text)';
}

/// A character cue together with the parentheticals and dialogue lines it
/// introduces.
///
/// Dual dialogue (two characters speaking simultaneously, marked with a
/// trailing `^` on the second character's cue) is represented by two
/// adjacent [FountainDialogueGroup]s in a document's block list: the
/// second one has [isDualDialogue] set to `true`. Consecutive groups are not
/// linked by direct object reference (which would make [FountainBlock]
/// equality and `toString` recurse through a cycle); pairing is instead a
/// matter of adjacency in the containing block list, exactly as it is a
/// matter of adjacency in the Fountain source itself.
class FountainDialogueGroup extends FountainBlock {
  /// Creates a [FountainDialogueGroup].
  const FountainDialogueGroup({
    required super.sourceRange,
    required this.character,
    required this.children,
    required this.isDualDialogue,
  });

  /// The character cue introducing this dialogue.
  final FountainCharacter character;

  /// The parentheticals and dialogue lines that make up this dialogue
  /// block, in source order. Every element is either a
  /// [FountainParenthetical] or a [FountainDialogueLine].
  final List<FountainBlock> children;

  /// Whether [character] was marked with a trailing `^`, meaning this group
  /// is spoken simultaneously with the dialogue group immediately preceding
  /// it. Mirrors [FountainCharacter.isDualDialogue].
  final bool isDualDialogue;

  @override
  List<Object?> get props => [character, children, isDualDialogue];

  @override
  String toString() =>
      'FountainDialogueGroup(${character.name}, ${children.length} lines)';
}

/// A transition, for example `CUT TO:`.
class FountainTransition extends FountainBlock {
  /// Creates a [FountainTransition].
  const FountainTransition({
    required super.sourceRange,
    required this.text,
    required this.forced,
  });

  /// The transition text, without its forcing `>` marker.
  final String text;

  /// Whether this transition was forced with a leading `>` rather than
  /// being recognized from its all-caps `...TO:` form.
  final bool forced;

  @override
  List<Object?> get props => [text, forced];

  @override
  String toString() => 'FountainTransition($text)';
}

/// A block of song lyrics, each source line of which was prefixed with `~`.
class FountainLyrics extends FountainBlock {
  /// Creates a [FountainLyrics] block.
  const FountainLyrics({required super.sourceRange, required this.lines});

  /// The lyrics text, one element per source line, with the leading `~`
  /// already stripped from each line.
  final List<String> lines;

  @override
  List<Object?> get props => [lines];

  @override
  String toString() => 'FountainLyrics(${lines.length} lines)';
}

/// A line of centered text, written as `> text <`.
class FountainCenteredText extends FountainBlock {
  /// Creates a [FountainCenteredText] block.
  const FountainCenteredText({required super.sourceRange, required this.text});

  /// The centered text, without its enclosing `>`/`<` markers.
  final String text;

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'FountainCenteredText($text)';
}

/// An organizational section heading, written as one to six leading `#`
/// characters (mirroring Markdown headers). Sections are structural only:
/// they are not part of the printed screenplay.
class FountainSection extends FountainBlock {
  /// Creates a [FountainSection].
  const FountainSection({
    required super.sourceRange,
    required this.level,
    required this.text,
  });

  /// The section's nesting level, from 1 (`#`) to 6 (`######`).
  final int level;

  /// The section's heading text, without its leading `#` characters.
  final String text;

  @override
  List<Object?> get props => [level, text];

  @override
  String toString() => 'FountainSection(level $level, $text)';
}

/// A synopsis line, written with a single leading `=`. Synopses are
/// organizational only: they are not part of the printed screenplay.
class FountainSynopsis extends FountainBlock {
  /// Creates a [FountainSynopsis].
  const FountainSynopsis({required super.sourceRange, required this.text});

  /// The synopsis text, without its leading `=`.
  final String text;

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'FountainSynopsis($text)';
}

/// A standalone authoring note, written as a `[[note]]` that occupies one or
/// more whole source lines by itself. An inline note that shares a line
/// with other text is instead represented as an inline note span within
/// that line's parent block (see `FountainInlineStyle.note`).
class FountainNoteBlock extends FountainBlock {
  /// Creates a [FountainNoteBlock].
  const FountainNoteBlock({required super.sourceRange, required this.text});

  /// The note's text, without its enclosing `[[`/`]]` markers.
  final String text;

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'FountainNoteBlock($text)';
}

/// A boneyard block comment, written as `/* ... */` and possibly spanning
/// several source lines and/or several other elements.
class FountainBoneyard extends FountainBlock {
  /// Creates a [FountainBoneyard] block.
  const FountainBoneyard({required super.sourceRange, required this.text});

  /// The comment's text, without its enclosing `/*`/`*/` markers.
  final String text;

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'FountainBoneyard($text)';
}

/// A forced page break, written as a line of three or more `=` characters.
class FountainPageBreak extends FountainBlock {
  /// Creates a [FountainPageBreak].
  const FountainPageBreak({required super.sourceRange});

  @override
  List<Object?> get props => [];

  @override
  String toString() => 'FountainPageBreak()';
}
