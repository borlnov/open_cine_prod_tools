// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:test/test.dart';

void main() {
  group('FountainCommentSpans', () {
    test('finds a boneyard and a note across several lines', () {
      const text = 'a /* x\ny */ b [[ n\nm ]] c';
      final boneyards = FountainCommentSpans.boneyards(text);
      final notes = FountainCommentSpans.notes(text);
      expect(text.substring(boneyards.single.start, boneyards.single.end), '/* x\ny */');
      expect(boneyards.single.isBoneyard, isTrue);
      expect(text.substring(notes.single.start, notes.single.end), '[[ n\nm ]]');
      expect(notes.single.isBoneyard, isFalse);
    });

    test('of reads boneyards first, so a note inside one is no span of its own', () {
      const text = '/* [[ a ]] */ [[ /* b ]] */';
      final spans = FountainCommentSpans.of(text);
      expect(spans.map((s) => text.substring(s.start, s.end)), ['/* [[ a ]] */', '/* b ]] */']);
    });

    test('scrub blanks the spans and keeps the newlines', () {
      const text = 'a [[x\ny]] b';
      expect(FountainCommentSpans.scrub(text, FountainCommentSpans.notes(text)), 'a    \n    b');
    });

    test('standaloneNotes keeps the notes alone on their lines', () {
      const text = '[[a]]\nx [[b]]\n  [[c\nd]]  \n[[e]] [[f]]';
      final notes = FountainCommentSpans.standaloneNotes(text);
      expect(notes.map((s) => text.substring(s.start, s.end)), ['[[a]]', '[[c\nd]]']);
    });

    test('scrubForClassification blanks boneyards and standalone notes only', () {
      const text = '/* a */ x\n[[n]]\ny [[i]]';
      expect(FountainCommentSpans.scrubForClassification(text), '        x\n     \ny [[i]]');
    });

    test('contains covers the markers', () {
      const span = FountainCommentSpan(start: 2, end: 5, isBoneyard: true);
      expect(span.contains(2), isTrue);
      expect(span.contains(4), isTrue);
      expect(span.contains(5), isFalse);
    });
  });
}
