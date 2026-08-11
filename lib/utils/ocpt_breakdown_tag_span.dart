// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Everything that is neither a letter nor a digit, at the very start of a passage: the opening
/// quote, bracket or dash a word may be preceded by, and the emphasis markers Fountain writes
/// around it (`*crown*`), which are source syntax rather than part of the name being tagged.
final _leadingNonWord = RegExp(r"^[^\p{L}\p{N}]+", unicode: true);

/// The same at the very end of a passage: the full stop, comma, closing bracket or quote a word is
/// written against.
final _trailingNonWord = RegExp(r"[^\p{L}\p{N}]+$", unicode: true);

/// The scene-relative span a passage clicked between [startOffset] and [endOffset] is really
/// tagged over: that span with the punctuation hugging either end left out, and clamped to
/// [sceneText]'s own bounds.
///
/// A clickable word is a whitespace-delimited run of non-whitespace characters (see
/// `OcptScriptWord`), so clicking `crown.` at the end of a sentence designates the full stop too —
/// which is what the popover would then pre-fill its search with, and what an element created from
/// it would be named. The passage names a thing of the production; the punctuation belongs to the
/// sentence around it, not to the thing. Only the two ends are touched: whatever a range spans in
/// between (`M. Dupont`, `l'épée`) is the passage the user picked, verbatim.
///
/// A passage holding no letter and no digit at all is returned as it stands, merely clamped:
/// trimming a lone `—` down to nothing would leave no passage to tag, and refusing the click is
/// `OcptBreakdownService`'s answer to give, not this one's.
///
/// This is deliberately the breakdown's own rule rather than the word layout's: a scenario coverage
/// range quotes a passage of the script, where the sentence's own punctuation belongs.
({int startOffset, int endOffset}) ocptBreakdownTaggedSpanOf({
  required String sceneText,
  required int startOffset,
  required int endOffset,
}) {
  final start = startOffset.clamp(0, sceneText.length);
  final end = endOffset.clamp(start, sceneText.length);

  final passage = sceneText.substring(start, end);
  final leadingLength = _leadingNonWord.firstMatch(passage)?.group(0)?.length ?? 0;
  if (leadingLength == passage.length) {
    // Nothing but punctuation: there is no word in there to trim down to.
    return (startOffset: start, endOffset: end);
  }

  final trailingLength = _trailingNonWord.firstMatch(passage)?.group(0)?.length ?? 0;

  return (startOffset: start + leadingLength, endOffset: end - trailingLength);
}
