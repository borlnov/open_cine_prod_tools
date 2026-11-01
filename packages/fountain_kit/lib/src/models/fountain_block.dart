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
  /// The location, in the original source, that this block was parsed from.
  final FountainSourceRange sourceRange;

  /// Creates a [FountainBlock].
  const FountainBlock({required this.sourceRange});
}

/// A scene heading, for example `INT. KITCHEN - DAY`.
class FountainSceneHeading extends FountainBlock {
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

  /// Creates a [FountainSceneHeading].
  const FountainSceneHeading({
    required super.sourceRange,
    required this.rawText,
    required this.headingText,
    required this.forcedMarker,
    this.sceneNumber,
  });

  /// Describe this [FountainSceneHeading] for debugging and logging.
  @override
  String toString() => 'FountainSceneHeading($headingText)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [rawText, headingText, forcedMarker, sceneNumber];
}

/// A paragraph of action/description text.
class FountainActionBlock extends FountainBlock {
  /// The action text, one element per source line, in source order, with
  /// original whitespace/indentation preserved and any leading forcing `!`
  /// already stripped.
  final List<String> lines;

  /// Whether this block was forced with a leading `!`.
  final bool forced;

  /// Creates a [FountainActionBlock].
  const FountainActionBlock({
    required super.sourceRange,
    required this.lines,
    required this.forced,
  });

  /// Describe this [FountainActionBlock] for debugging and logging.
  @override
  String toString() => 'FountainActionBlock(${lines.length} lines)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [lines, forced];
}

/// A character cue introducing a block of dialogue, for example `SARAH
/// (O.S.)`.
///
/// A [FountainCharacter] never appears on its own in
/// [FountainDocument.blocks]: it is always the [FountainDialogueGroup.character]
/// of the dialogue block it introduces.
class FountainCharacter extends FountainBlock {
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

  /// Creates a [FountainCharacter].
  const FountainCharacter({
    required super.sourceRange,
    required this.name,
    required this.isDualDialogue,
    this.extension,
  });

  /// Describe this [FountainCharacter] for debugging and logging.
  @override
  String toString() {
    final suffix = extension == null ? '' : ' ($extension)';
    return 'FountainCharacter($name$suffix)';
  }

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [name, extension, isDualDialogue];
}

/// A parenthetical direction inside a block of dialogue, for example
/// `(beat)`.
class FountainParenthetical extends FountainBlock {
  /// The parenthetical's text, without its enclosing parentheses.
  final String text;

  /// Creates a [FountainParenthetical].
  const FountainParenthetical({required super.sourceRange, required this.text});

  /// Describe this [FountainParenthetical] for debugging and logging.
  @override
  String toString() => 'FountainParenthetical($text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text];
}

/// A single line of spoken dialogue inside a [FountainDialogueGroup].
class FountainDialogueLine extends FountainBlock {
  /// The dialogue text. A line that was blank in the source but kept
  /// meaningful by trailing whitespace (see the Fountain spec) is
  /// represented here as an empty string.
  final String text;

  /// Creates a [FountainDialogueLine].
  const FountainDialogueLine({required super.sourceRange, required this.text});

  /// Describe this [FountainDialogueLine] for debugging and logging.
  @override
  String toString() => 'FountainDialogueLine($text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text];
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

  /// Creates a [FountainDialogueGroup].
  const FountainDialogueGroup({
    required super.sourceRange,
    required this.character,
    required this.children,
    required this.isDualDialogue,
  });

  /// Describe this [FountainDialogueGroup] for debugging and logging.
  @override
  String toString() => 'FountainDialogueGroup(${character.name}, ${children.length} lines)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [character, children, isDualDialogue];
}

/// A transition, for example `CUT TO:`.
class FountainTransition extends FountainBlock {
  /// The transition text, without its forcing `>` marker.
  final String text;

  /// Whether this transition was forced with a leading `>` rather than
  /// being recognized from its all-caps `...TO:` form.
  final bool forced;

  /// Creates a [FountainTransition].
  const FountainTransition({required super.sourceRange, required this.text, required this.forced});

  /// Describe this [FountainTransition] for debugging and logging.
  @override
  String toString() => 'FountainTransition($text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text, forced];
}

/// A block of song lyrics, each source line of which was prefixed with `~`.
class FountainLyrics extends FountainBlock {
  /// The lyrics text, one element per source line, with the leading `~`
  /// already stripped from each line.
  final List<String> lines;

  /// Creates a [FountainLyrics] block.
  const FountainLyrics({required super.sourceRange, required this.lines});

  /// Describe this [FountainLyrics] for debugging and logging.
  @override
  String toString() => 'FountainLyrics(${lines.length} lines)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [lines];
}

/// A line of centered text, written as `> text <`.
class FountainCenteredText extends FountainBlock {
  /// The centered text, without its enclosing `>`/`<` markers.
  final String text;

  /// Creates a [FountainCenteredText] block.
  const FountainCenteredText({required super.sourceRange, required this.text});

  /// Describe this [FountainCenteredText] for debugging and logging.
  @override
  String toString() => 'FountainCenteredText($text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text];
}

/// An organizational section heading, written as one to six leading `#`
/// characters (mirroring Markdown headers). Sections are structural only:
/// they are not part of the printed screenplay.
class FountainSection extends FountainBlock {
  /// The section's nesting level, from 1 (`#`) to 6 (`######`).
  final int level;

  /// The section's heading text, without its leading `#` characters.
  final String text;

  /// Creates a [FountainSection].
  const FountainSection({required super.sourceRange, required this.level, required this.text});

  /// Describe this [FountainSection] for debugging and logging.
  @override
  String toString() => 'FountainSection(level $level, $text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [level, text];
}

/// A synopsis line, written with a single leading `=`. Synopses are
/// organizational only: they are not part of the printed screenplay.
class FountainSynopsis extends FountainBlock {
  /// The synopsis text, without its leading `=`.
  final String text;

  /// Creates a [FountainSynopsis].
  const FountainSynopsis({required super.sourceRange, required this.text});

  /// Describe this [FountainSynopsis] for debugging and logging.
  @override
  String toString() => 'FountainSynopsis($text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text];
}

/// A standalone authoring note, written as a `[[note]]` that occupies one or
/// more whole source lines by itself. An inline note that shares a line
/// with other text is instead represented as an inline note span within
/// that line's parent block (see `FountainInlineStyle.note`).
class FountainNoteBlock extends FountainBlock {
  /// The note's text, without its enclosing `[[`/`]]` markers.
  final String text;

  /// Creates a [FountainNoteBlock].
  const FountainNoteBlock({required super.sourceRange, required this.text});

  /// Describe this [FountainNoteBlock] for debugging and logging.
  @override
  String toString() => 'FountainNoteBlock($text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text];
}

/// A boneyard block comment, written as `/* ... */` and possibly spanning
/// several source lines and/or several other elements.
class FountainBoneyard extends FountainBlock {
  /// The comment's text, without its enclosing `/*`/`*/` markers.
  final String text;

  /// Creates a [FountainBoneyard] block.
  const FountainBoneyard({required super.sourceRange, required this.text});

  /// Describe this [FountainBoneyard] for debugging and logging.
  @override
  String toString() => 'FountainBoneyard($text)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text];
}

/// A forced page break, written as a line of three or more `=` characters.
class FountainPageBreak extends FountainBlock {
  /// Creates a [FountainPageBreak].
  const FountainPageBreak({required super.sourceRange});

  /// Describe this [FountainPageBreak] for debugging and logging.
  @override
  String toString() => 'FountainPageBreak()';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [];
}
