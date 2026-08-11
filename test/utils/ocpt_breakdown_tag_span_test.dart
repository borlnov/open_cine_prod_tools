// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_tag_span.dart';

/// The passage [sceneText] holds between the offsets [ocptBreakdownTaggedSpanOf] narrows
/// `[startOffset, endOffset)` down to: what the popover pre-fills its search with.
String _taggedTextOf(String sceneText, int startOffset, int endOffset) {
  final span = ocptBreakdownTaggedSpanOf(
    sceneText: sceneText,
    startOffset: startOffset,
    endOffset: endOffset,
  );
  return sceneText.substring(span.startOffset, span.endOffset);
}

void main() {
  test("a passage with nothing around it is left exactly as it is", () {
    const text = "A lamp sits on the desk";
    expect(ocptBreakdownTaggedSpanOf(sceneText: text, startOffset: 2, endOffset: 6), (
      startOffset: 2,
      endOffset: 6,
    ));
  });

  test("the punctuation a word is written against is left out of the span", () {
    const text = 'A lamp sits on the "desk", waiting.';

    expect(_taggedTextOf(text, 19, 26), "desk");
    expect(_taggedTextOf(text, 2, 35), 'lamp sits on the "desk", waiting');
  });

  test("the emphasis markers Fountain writes around a word are left out too", () {
    const text = "She lifts the *crown* again";
    expect(_taggedTextOf(text, 14, 21), "crown");
  });

  test("punctuation inside a passage is kept, being part of what was picked", () {
    const text = "M. Dupont brandit l'épée du roi.";

    expect(_taggedTextOf(text, 0, 9), "M. Dupont");
    expect(_taggedTextOf(text, 18, 31), "l'épée du roi");
  });

  test("a passage made of punctuation alone is returned as it stands", () {
    const text = "He waits — then leaves.";
    expect(ocptBreakdownTaggedSpanOf(sceneText: text, startOffset: 9, endOffset: 10), (
      startOffset: 9,
      endOffset: 10,
    ));
  });

  test("offsets reaching past the scene's own text are clamped to it", () {
    const text = "A lamp.";

    expect(ocptBreakdownTaggedSpanOf(sceneText: text, startOffset: 2, endOffset: 40), (
      startOffset: 2,
      endOffset: 6,
    ));
    expect(ocptBreakdownTaggedSpanOf(sceneText: text, startOffset: -3, endOffset: 6), (
      startOffset: 0,
      endOffset: 6,
    ));
  });
}
