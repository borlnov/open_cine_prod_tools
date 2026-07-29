// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';

/// One run of a word's printed text: the characters themselves and the inline emphasis they carry.
///
/// A single word can hold more than one run (`*two*words` prints `two` in italic immediately
/// followed by a roman `words`), which is why a word's display text is a list of these rather than
/// one string and one style.
typedef OcptFountainDisplayRun = ({String text, FountainInlineStyle style});

/// The **printed** text of every word of [block], in word order, with every Fountain marker
/// resolved away rather than shown: emphasis markers (`*`, `**`, `***`, `_`), the leading forcing
/// character of a forced line, a scene heading's trailing `#N#`, and inline notes (`[[…]]`, never
/// part of the printed screenplay).
///
/// Each word's runs carry the whitespace separating it from the next word (or ending the line), so
/// a renderer drawing one box per word covers the gaps between words too — see
/// `OcptShotCoverageDialog`, whose whole point is that a word's click target and its coverage
/// highlight both extend over that whitespace.
///
/// **The source offsets are untouched.** This only decides what is *shown*: a word still covers
/// exactly the `OcptShotCoverageWord.startOffset`/`endOffset` range it always did, markers
/// included, so a coverage range recorded from a click keeps pointing at the source text the
/// screenplay actually holds. That is why this returns display runs per existing word rather than
/// re-splitting a cleaned-up string into new words.
List<List<OcptFountainDisplayRun>> ocptFountainWordDisplayRuns(OcptShotCoverageBlock block) {
  final line = block.text;
  final styles = List<FountainInlineStyle>.filled(line.length, FountainInlineStyle.plain);
  final isVisible = List<bool>.filled(line.length, true);

  _applyInlineSpans(line: line, styles: styles, isVisible: isVisible);
  _hideLineMarkers(line: line, type: block.type, isVisible: isVisible);

  return [
    for (var i = 0; i < block.words.length; i++)
      _runsOf(
        line: line,
        styles: styles,
        isVisible: isVisible,
        // Relative to the line rather than to the scene: a word carries the whitespace up to the
        // next word, or to the end of the line for the last one.
        startInLine: block.words[i].startOffset - block.startOffset,
        endInLine: i + 1 < block.words.length
            ? block.words[i + 1].startOffset - block.startOffset
            : line.length,
      ),
  ];
}

/// Resolves [line]'s inline emphasis, marking each character's [styles] entry and hiding the
/// emphasis markers themselves in [isVisible].
///
/// A span's own text is already marker-free, so the markers are the characters its source range
/// holds around it — symmetrically, the same number on each side. A span whose source range and
/// printed text don't line up that way (an escaped `\*`, say, which is one source character longer
/// on one side only) is left fully visible rather than guessed at: showing a stray marker is a far
/// smaller sin than hiding a character the writer typed.
void _applyInlineSpans({
  required String line,
  required List<FountainInlineStyle> styles,
  required List<bool> isVisible,
}) {
  for (final span in const FountainInlineParser().parse(line)) {
    final start = span.sourceRange.startOffset;
    final end = span.sourceRange.endOffset;
    if (start < 0 || end > line.length) {
      continue;
    }

    if (span.style == FountainInlineStyle.note) {
      // An inline note is authoring-only: it is not part of the printed screenplay at all.
      isVisible.fillRange(start, end, false);
      continue;
    }

    final markerLength = (end - start - span.text.length) ~/ 2;
    final hasSymmetricMarkers =
        markerLength > 0 &&
        (end - start - span.text.length).isEven &&
        line.substring(start + markerLength, end - markerLength) == span.text;

    for (var i = start; i < end; i++) {
      styles[i] = span.style;
      if (hasSymmetricMarkers && (i < start + markerLength || i >= end - markerLength)) {
        isVisible[i] = false;
      }
    }
  }
}

/// Hides the markers a whole line carries rather than a run inside it: the forcing character of a
/// forced line, the closing `<` of centered text, and a scene heading's trailing `#N#`.
///
/// A forcing character is only ever hidden where its line type says one may sit, so an action line
/// legitimately starting with `!` after being forced reads as printed while a dialogue line
/// starting with the same character keeps it.
void _hideLineMarkers({
  required String line,
  required FountainLineType type,
  required List<bool> isVisible,
}) {
  final leadingIndex = line.indexOf(RegExp(r'\S'));
  if (leadingIndex == -1) {
    return;
  }

  final forcingCharacter = switch (type) {
    FountainLineType.sceneHeading => ".",
    FountainLineType.action => "!",
    FountainLineType.character => "@",
    FountainLineType.transition || FountainLineType.centeredText => ">",
    FountainLineType.lyrics => "~",
    FountainLineType.synopsis => "=",
    FountainLineType.section => "#",
    FountainLineType.parenthetical ||
    FountainLineType.dialogue ||
    FountainLineType.pageBreak ||
    FountainLineType.blank => null,
  };

  if (forcingCharacter != null) {
    // A section's marker is one to six `#`; every other forcing marker is a single character.
    var index = leadingIndex;
    while (index < line.length && line[index] == forcingCharacter) {
      isVisible[index] = false;
      index++;
      if (type != FountainLineType.section) {
        break;
      }
    }
  }

  if (type == FountainLineType.centeredText) {
    final trailingIndex = line.lastIndexOf("<");
    if (trailingIndex != -1) {
      isVisible[trailingIndex] = false;
    }
  }

  if (type == FountainLineType.sceneHeading) {
    final sceneNumber = RegExp(r'#([A-Za-z0-9.\-]+)#\s*$').firstMatch(line);
    if (sceneNumber != null) {
      isVisible.fillRange(sceneNumber.start, sceneNumber.end, false);
    }
  }
}

/// Groups the visible characters of `line[startInLine:endInLine]` into consecutive runs of one
/// style each, skipping every character hidden by a marker.
List<OcptFountainDisplayRun> _runsOf({
  required String line,
  required List<FountainInlineStyle> styles,
  required List<bool> isVisible,
  required int startInLine,
  required int endInLine,
}) {
  final runs = <OcptFountainDisplayRun>[];
  final buffer = StringBuffer();
  var currentStyle = FountainInlineStyle.plain;

  void flush() {
    if (buffer.isNotEmpty) {
      runs.add((text: buffer.toString(), style: currentStyle));
      buffer.clear();
    }
  }

  for (var i = startInLine.clamp(0, line.length); i < endInLine.clamp(0, line.length); i++) {
    if (!isVisible[i]) {
      continue;
    }
    if (buffer.isNotEmpty && styles[i] != currentStyle) {
      flush();
    }
    currentStyle = styles[i];
    buffer.write(line[i]);
  }
  flush();

  return runs;
}
