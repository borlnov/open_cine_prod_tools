// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_text_controller.dart';
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';
import 'package:spell_kit/spell_kit.dart';

/// Depth-first search for the first [TextSpan] (in [root]'s own tree) whose own [TextSpan.text] is
/// exactly [target] — the shape [OcptEditorSearchTextController.buildTextSpan] produces one segment
/// per boundary-delimited run of text, so a span whose covering match/misspelling exactly matches a
/// word's own bounds shows up as one leaf carrying exactly that word.
TextSpan? _findSpanWithText(InlineSpan root, String target) {
  if (root is TextSpan) {
    if (root.text == target) {
      return root;
    }
    for (final child in root.children ?? const <InlineSpan>[]) {
      final found = _findSpanWithText(child, target);
      if (found != null) {
        return found;
      }
    }
  }
  return null;
}

/// Whether any leaf of [root]'s tree carries a wavy underline decoration — used to assert that
/// nothing at all is underlined once every misspelling has been dropped as out of range.
bool _anySpanIsUnderlined(InlineSpan root) {
  if (root is TextSpan) {
    if (root.style?.decoration == TextDecoration.underline) {
      return true;
    }
    for (final child in root.children ?? const <InlineSpan>[]) {
      if (_anySpanIsUnderlined(child)) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  /// Builds a widget tree and hands back a [BuildContext] from inside it — [buildTextSpan] takes
  /// one, but never actually reads anything from it (the search/spell colours are fixed constants,
  /// not theme-derived), so any mounted context does.
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return capturedContext;
  }

  testWidgets(
    "a misspelling inside a search match carries both the match's background wash and the "
    "misspelling's wavy underline, in the same span",
    (tester) async {
      final context = await pumpContext(tester);
      const text = 'The wrold is round.';
      const word = 'wrold';
      final wordStart = text.indexOf(word);
      final wordEnd = wordStart + word.length;

      final controller = OcptEditorSearchTextController(text: text);
      controller.updateMatches([OcptTextMatch(start: wordStart, end: wordEnd)], 0);
      controller.updateSpellCheckRanges([SpellRange(wordStart, wordEnd)]);

      final span = controller.buildTextSpan(context: context, withComposing: false);
      final wordSpan = _findSpanWithText(span, word);

      expect(wordSpan, isNotNull);
      expect(wordSpan!.style?.backgroundColor, ocptEditorSearchCurrentMatchColor);
      expect(wordSpan.style?.decoration, TextDecoration.underline);
      expect(wordSpan.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(wordSpan.style?.decorationColor, ocptEditorSpellCheckErrorColor);

      controller.dispose();
    },
  );

  testWidgets(
    'a misspelling outside any search match carries the wavy underline alone, and a search match '
    'holding no misspelling carries the background wash alone',
    (tester) async {
      final context = await pumpContext(tester);
      const text = 'A wrold with a match.';
      const misspelling = 'wrold';
      const match = 'match';
      final misspellingStart = text.indexOf(misspelling);
      final misspellingEnd = misspellingStart + misspelling.length;
      final matchStart = text.indexOf(match);
      final matchEnd = matchStart + match.length;

      final controller = OcptEditorSearchTextController(text: text);
      controller.updateMatches([OcptTextMatch(start: matchStart, end: matchEnd)], 0);
      controller.updateSpellCheckRanges([SpellRange(misspellingStart, misspellingEnd)]);

      final span = controller.buildTextSpan(context: context, withComposing: false);

      final misspellingSpan = _findSpanWithText(span, misspelling);
      expect(misspellingSpan, isNotNull);
      expect(misspellingSpan!.style?.decoration, TextDecoration.underline);
      expect(misspellingSpan.style?.backgroundColor, isNull);

      final matchSpan = _findSpanWithText(span, match);
      expect(matchSpan, isNotNull);
      expect(matchSpan!.style?.backgroundColor, ocptEditorSearchCurrentMatchColor);
      expect(matchSpan.style?.decoration, isNot(TextDecoration.underline));

      controller.dispose();
    },
  );

  testWidgets(
    'a spelling range past the current text end is dropped rather than fed into a substring',
    (tester) async {
      final context = await pumpContext(tester);
      const text = 'Short text.';

      final controller = OcptEditorSearchTextController(text: text);
      // Computed against a longer text this controller has since moved past (the plan's own M3
      // trap: a spelling range arrives one isolate round trip later than a search match does, so
      // it is more exposed to this than a match is).
      controller.updateSpellCheckRanges([const SpellRange(0, text.length + 50)]);

      expect(
        () => controller.buildTextSpan(context: context, withComposing: false),
        returnsNormally,
      );

      final span = controller.buildTextSpan(context: context, withComposing: false);
      expect(_anySpanIsUnderlined(span), isFalse);
      expect(span.toPlainText(), text);

      controller.dispose();
    },
  );

  testWidgets(
    'a spelling range starting past the current text end is dropped the same way',
    (tester) async {
      final context = await pumpContext(tester);
      const text = 'Short text.';

      final controller = OcptEditorSearchTextController(text: text);
      controller.updateSpellCheckRanges([const SpellRange(text.length + 5, text.length + 10)]);

      expect(
        () => controller.buildTextSpan(context: context, withComposing: false),
        returnsNormally,
      );

      final span = controller.buildTextSpan(context: context, withComposing: false);
      expect(_anySpanIsUnderlined(span), isFalse);

      controller.dispose();
    },
  );

  test('updateSpellCheckRanges is a no-op, and notifies no listener, when given the ranges '
      'already held', () {
    final controller = OcptEditorSearchTextController(text: 'Some text.');
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.updateSpellCheckRanges(const [SpellRange(0, 4)]);
    expect(notifications, 1);

    controller.updateSpellCheckRanges(const [SpellRange(0, 4)]);
    expect(notifications, 1);

    controller.updateSpellCheckRanges(const [SpellRange(0, 5)]);
    expect(notifications, 2);

    controller.dispose();
  });
}
