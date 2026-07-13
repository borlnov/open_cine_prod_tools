// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The structural role of a single source line, as determined by
/// [FountainLineClassifier].
enum FountainLineType {
  /// A line with no content (or only whitespace that does not carry the
  /// "preserved blank dialogue line" meaning described in the Fountain
  /// spec).
  blank,

  /// A forced page break, `===`.
  pageBreak,

  /// An organizational section heading, `# text` through `###### text`.
  section,

  /// A synopsis line, `= text`.
  synopsis,

  /// A scene heading, for example `INT. KITCHEN - DAY`.
  sceneHeading,

  /// A transition, for example `CUT TO:`.
  transition,

  /// Centered text, `> text <`.
  centeredText,

  /// A lyrics line, `~ text`.
  lyrics,

  /// A character cue introducing dialogue.
  character,

  /// A parenthetical direction inside a dialogue block.
  parenthetical,

  /// A line of spoken dialogue.
  dialogue,

  /// A line of action/description text; the default when nothing more
  /// specific applies.
  action,
}

/// First parsing pass: classifies every source line of a Fountain document
/// body (title page and boneyard/standalone-note lines already removed)
/// into a [FountainLineType], using the line's own leading forcing
/// character (if any) and the type of the surrounding lines.
///
/// This class is a pure function of its input: it holds no state between
/// calls to [classify], so a caller can re-classify any subset of a
/// document's lines as long as it passes enough surrounding context.
class FountainLineClassifier {
  /// Creates a [FountainLineClassifier].
  const FountainLineClassifier();

  /// Matches the leading token of an (auto-detected, non-forced) scene
  /// heading: `INT`, `EXT`, `EST`, `INT./EXT`, `INT/EXT`, `EXT./INT`,
  /// `EXT/INT` or `I/E`, immediately followed by a `.` or whitespace.
  static final RegExp _sceneHeadingPrefix = RegExp(
    r'^(INT\.?/EXT|EXT\.?/INT|I/E|INT|EXT|EST)[.\s]',
    caseSensitive: false,
  );

  /// Matches a forced page break: a line made up of three or more `=`
  /// characters and nothing else.
  static final RegExp _pageBreak = RegExp(r'^={3,}$');

  /// Matches a section heading: one to six leading `#` characters,
  /// optionally followed by more text.
  static final RegExp _section = RegExp(r'^(#{1,6})\s*(.*)$');

  /// Classifies every line of [lines] and returns one [FountainLineType]
  /// per line, in the same order.
  List<FountainLineType> classify(List<String> lines) {
    final types = List<FountainLineType>.filled(
      lines.length,
      FountainLineType.blank,
    );
    for (var index = 0; index < lines.length; index++) {
      final previousType = index == 0 ? null : types[index - 1];
      final nextRawLine = index + 1 < lines.length ? lines[index + 1] : null;
      types[index] = classifyLine(
        lines[index],
        previousType: previousType,
        nextRawLine: nextRawLine,
      );
    }
    return types;
  }

  /// Determines the [FountainLineType] of [rawLine] given just enough
  /// surrounding context to reproduce every context-sensitive rule in
  /// [classify]: the [FountainLineType] of the line immediately before it
  /// ([previousType], `null` at the start of the document) and the raw text
  /// of the line immediately after it ([nextRawLine], `null` at the end of
  /// the document). No rule in this classifier looks further than one line
  /// in either direction, so this is enough context to classify any single
  /// candidate line in isolation, which is what lets a line writer decide,
  /// line by line, whether a forcing marker is needed.
  FountainLineType classifyLine(
    String rawLine, {
    required FountainLineType? previousType,
    required String? nextRawLine,
  }) {
    final trimmed = rawLine.trim();

    if (trimmed.isEmpty) {
      // A line that is empty in `trim()` terms but was not truly empty in
      // the source (i.e. it holds meaningful trailing whitespace) keeps a
      // dialogue block open, per the Fountain spec.
      if (rawLine.isNotEmpty && _continuesDialogue(previousType)) {
        return FountainLineType.dialogue;
      }
      return FountainLineType.blank;
    }

    if (_pageBreak.hasMatch(trimmed)) {
      return FountainLineType.pageBreak;
    }

    if (_section.hasMatch(trimmed)) {
      return FountainLineType.section;
    }

    if (trimmed.startsWith('=')) {
      return FountainLineType.synopsis;
    }

    if (rawLine.startsWith('!')) {
      return FountainLineType.action;
    }

    if (rawLine.startsWith('.') && !rawLine.startsWith('..')) {
      return FountainLineType.sceneHeading;
    }

    if (rawLine.startsWith('@')) {
      return FountainLineType.character;
    }

    if (trimmed.startsWith('>')) {
      return trimmed.endsWith('<')
          ? FountainLineType.centeredText
          : FountainLineType.transition;
    }

    if (rawLine.startsWith('~')) {
      return FountainLineType.lyrics;
    }

    final precededByBlank =
        previousType == null || previousType == FountainLineType.blank;
    final followedByBlank = nextRawLine == null || nextRawLine.trim().isEmpty;

    if (_sceneHeadingPrefix.hasMatch(trimmed) &&
        precededByBlank &&
        followedByBlank) {
      return FountainLineType.sceneHeading;
    }

    if (_isTransitionCandidate(trimmed) && precededByBlank && followedByBlank) {
      return FountainLineType.transition;
    }

    if (_isCharacterCandidate(trimmed) &&
        precededByBlank &&
        nextRawLine != null &&
        nextRawLine.trim().isNotEmpty) {
      return FountainLineType.character;
    }

    if (trimmed.startsWith('(') &&
        trimmed.endsWith(')') &&
        _continuesDialogue(previousType)) {
      return FountainLineType.parenthetical;
    }

    if (_continuesDialogue(previousType)) {
      return FountainLineType.dialogue;
    }

    return FountainLineType.action;
  }

  /// Whether [type] is a dialogue-block element that keeps the dialogue
  /// block open for the line immediately after it.
  bool _continuesDialogue(FountainLineType? type) =>
      type == FountainLineType.character ||
      type == FountainLineType.parenthetical ||
      type == FountainLineType.dialogue;

  /// Whether [trimmed] looks like an (unforced) character cue: all-caps
  /// text, optionally with a parenthetical extension and/or a trailing `^`
  /// dual-dialogue marker.
  bool _isCharacterCandidate(String trimmed) {
    var candidate = trimmed;
    if (candidate.endsWith('^')) {
      candidate = candidate.substring(0, candidate.length - 1).trim();
    }
    return _isAllCaps(candidate);
  }

  /// Whether [trimmed] looks like an (unforced) transition: all-caps text
  /// ending with `TO:`.
  bool _isTransitionCandidate(String trimmed) =>
      trimmed.endsWith('TO:') && _isAllCaps(trimmed);

  /// Whether [text] contains no lowercase letters and at least one cased
  /// letter (so that, for example, a line of only digits and punctuation
  /// does not count as "all caps").
  bool _isAllCaps(String text) =>
      text == text.toUpperCase() && text != text.toLowerCase();
}
