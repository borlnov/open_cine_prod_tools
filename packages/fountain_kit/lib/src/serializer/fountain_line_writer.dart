// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';

/// Writes a single display line of Fountain text back out as a raw source
/// line, deciding on the fly whether the line needs a forcing marker to
/// (re-)classify as its intended [FountainLineType].
///
/// This is the per-line counterpart to [FountainLineClassifier]: where the
/// classifier answers "what type is this raw line", [FountainLineWriter]
/// answers "what raw line produces this type". It is meant to be driven one
/// line at a time, left to right, passing each already-written line's type
/// as the next line's `previousType` and a preview of each not-yet-written
/// line's plain text as the current line's `nextRawLine` — the same
/// context [FountainLineClassifier.classifyLine] needs.
///
/// Six of the eleven non-blank [FountainLineType]s ([FountainLineType.
/// sceneHeading], [FountainLineType.action], [FountainLineType.character],
/// [FountainLineType.transition], [FountainLineType.lyrics] and
/// [FountainLineType.synopsis], plus [FountainLineType.section]) have a
/// single-character forcing marker: [writeLine] prepends it only when
/// `hadForcingMarker` is set, or when classifying the plain text would not
/// already yield the intended [FountainLineType] in context (for example
/// because the intended type has no auto-detection rule at all, as for
/// lyrics, section and synopsis, or because the surrounding context does not
/// satisfy the auto-detection rule, as for a scene heading with no blank
/// line around it). [FountainLineType.centeredText] and
/// [FountainLineType.pageBreak] have no plain form at all and are always
/// wrapped/emitted literally. [FountainLineType.dialogue] and
/// [FountainLineType.parenthetical] have no forcing marker in the Fountain
/// spec: [writeLine] always emits their text verbatim, even when the
/// surrounding context means it will not round-trip back to the same type
/// (see the dialogue/parenthetical fallback documented on the app-side
/// codec that calls this class).
class FountainLineWriter {
  /// Creates a [FountainLineWriter].
  const FountainLineWriter({
    this.classifier = const FountainLineClassifier(),
  });

  /// The classifier used to decide whether a candidate line needs a forcing
  /// marker to (re-)classify as its intended type.
  final FountainLineClassifier classifier;

  /// Renders [text] as a raw Fountain source line of type [type].
  ///
  /// [hadForcingMarker] should reflect whether the line this was decoded
  /// from originally carried an explicit forcing marker; when set, the
  /// marker is preserved even if [text] would already auto-detect
  /// correctly. [previousType] and [nextRawLine] give the same one-line
  /// context [FountainLineClassifier.classifyLine] takes, built from
  /// already-written earlier lines and a preview of the not-yet-written
  /// next line's plain text.
  ///
  /// [sectionLevel] (1-6) selects the number of leading `#` characters
  /// emitted for [FountainLineType.section]; it is ignored for every other
  /// type.
  String writeLine({
    required String text,
    required FountainLineType type,
    required bool hadForcingMarker,
    required FountainLineType? previousType,
    required String? nextRawLine,
    int sectionLevel = 1,
  }) {
    assert(
      sectionLevel >= 1 && sectionLevel <= 6,
      'sectionLevel must be between 1 and 6, was $sectionLevel',
    );
    return switch (type) {
      FountainLineType.blank => throw ArgumentError.value(
        type,
        'type',
        'FountainLineWriter never writes blank lines: blank source lines '
            'are represented as ocptBlankLinesBefore metadata, not as a '
            'written line',
      ),
      FountainLineType.dialogue ||
      FountainLineType.parenthetical => text,
      FountainLineType.pageBreak => '===',
      FountainLineType.centeredText => '> $text <',
      FountainLineType.sceneHeading => _writeWithPrefixMarker(
        text: text,
        type: type,
        marker: '.',
        hadForcingMarker: hadForcingMarker,
        previousType: previousType,
        nextRawLine: nextRawLine,
      ),
      FountainLineType.action => _writeWithPrefixMarker(
        text: text,
        type: type,
        marker: '!',
        hadForcingMarker: hadForcingMarker,
        previousType: previousType,
        nextRawLine: nextRawLine,
      ),
      FountainLineType.character => _writeWithPrefixMarker(
        text: text,
        type: type,
        marker: '@',
        hadForcingMarker: hadForcingMarker,
        previousType: previousType,
        nextRawLine: nextRawLine,
      ),
      FountainLineType.transition => _writeWithPrefixMarker(
        text: text,
        type: type,
        marker: '>',
        hadForcingMarker: hadForcingMarker,
        previousType: previousType,
        nextRawLine: nextRawLine,
      ),
      FountainLineType.lyrics => _writeWithPrefixMarker(
        text: text,
        type: type,
        marker: '~',
        hadForcingMarker: hadForcingMarker,
        previousType: previousType,
        nextRawLine: nextRawLine,
      ),
      FountainLineType.synopsis => _writeWithPrefixMarker(
        text: text,
        type: type,
        marker: '= ',
        hadForcingMarker: hadForcingMarker,
        previousType: previousType,
        nextRawLine: nextRawLine,
      ),
      FountainLineType.section => _writeWithPrefixMarker(
        text: text,
        type: type,
        marker: '${'#' * sectionLevel} ',
        hadForcingMarker: hadForcingMarker,
        previousType: previousType,
        nextRawLine: nextRawLine,
      ),
    };
  }

  /// Prepends [marker] to [text] unless [text] would already classify as
  /// [type] on its own, in the given [previousType]/[nextRawLine] context,
  /// and [hadForcingMarker] is not set.
  String _writeWithPrefixMarker({
    required String text,
    required FountainLineType type,
    required String marker,
    required bool hadForcingMarker,
    required FountainLineType? previousType,
    required String? nextRawLine,
  }) {
    final autoDetects =
        classifier.classifyLine(
          text,
          previousType: previousType,
          nextRawLine: nextRawLine,
        ) ==
        type;
    if (autoDetects && !hadForcingMarker) {
      return text;
    }
    return '$marker$text';
  }
}
