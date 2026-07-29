// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_dialog.dart';

/// Wraps [child] in the app's own light theme — the dialog paints its backdrop from the
/// `OcptSpecificColors` extension, which only a theme built from [ocptTheme] carries — plus the
/// localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// Gives the test surface room for a whole simulated page, restoring the default size once the
/// test ends: the dialog is as wide as the page setup's own sheet, which the default 800x600
/// surface would otherwise clamp.
Future<void> _useLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A realistic scene: heading, an action line, a character cue, a parenthetical and a dialogue
/// line, matching the fixture `OcptShotCoverageLayout.of`'s own tests use.
const _sceneId = "scene-1";
const _sceneText = 'INT. HOUSE - DAY\n\nJohn walks in.\n\nJOHN\n(whispering)\nHello there.';

/// Builds the layout every test in this file lays its scene out from.
OcptShotCoverageLayout _buildLayout() =>
    OcptShotCoverageLayout.of(sceneId: _sceneId, sceneText: _sceneText);

/// Builds an [OcptShotCoverageRange] test double with sensible defaults for the fields a given
/// test doesn't care about.
OcptShotCoverageRange _buildRange({
  required int startOffset,
  required int endOffset,
  String id = "range",
  String sceneId = _sceneId,
}) => OcptShotCoverageRange(
  id: id,
  sceneId: sceneId,
  startOffset: startOffset,
  endOffset: endOffset,
  coveredTextDigest: "irrelevant-for-this-test",
  isStale: false,
);

/// Builds a dialog with a sensible default of every field, only the fields a given test cares
/// about overridden.
Widget _buildDialog({
  OcptShotCoverageLayout? layout,
  List<OcptShotCoverageRange> ownRanges = const [],
  Map<String, List<OcptShotCoverageRange>> otherShotsRanges = const {},
  OcptShotCoverageAnchor? pendingAnchor,
  void Function(int blockStartOffset, int wordStartOffset, int wordEndOffset)? onWordTapped,
  VoidCallback? onClearAll,
}) => OcptShotCoverageDialog(
  shotCode: "1/3",
  sequenceHeading: "INT. HOUSE - DAY",
  layout: layout ?? _buildLayout(),
  pageSetup: const OcptPageSetup.standard(),
  ownRanges: ownRanges,
  otherShotsRanges: otherShotsRanges,
  pendingAnchor: pendingAnchor,
  onWordTapped: onWordTapped ?? (_, __, ___) {},
  onClearAll: onClearAll ?? () {},
);

/// The background colour the sheet paints the word rendered as [text] with, or null when it paints
/// none at all (an uncovered word).
///
/// A word's own box carries the whitespace that follows it in the source, so a word is found by
/// the text it is rendered *with*, trailing space included.
Color? _backgroundOfWord(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return container.color;
}

void main() {
  testWidgets("typesets the sequence on a paper sheet, one word box per word", (tester) async {
    await _useLargeSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildDialog()));

    // A scene heading prints upper-cased, and every word keeps the whitespace that follows it.
    expect(find.text("INT. "), findsOneWidget);
    expect(find.text("HOUSE "), findsOneWidget);
    expect(find.text("John "), findsOneWidget);
    expect(find.text("there."), findsOneWidget);
  });

  testWidgets("shows the shot's code and its sequence heading", (tester) async {
    await _useLargeSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildDialog()));

    expect(find.text("Coverage — Shot 1/3"), findsOneWidget);
    expect(find.text("INT. HOUSE - DAY"), findsOneWidget);
  });

  testWidgets("tapping a word reports its block start offset and its own offsets", (tester) async {
    await _useLargeSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    final houseWord = headingBlock.words[1];

    (int, int, int)? reported;
    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          layout: layout,
          onWordTapped: (blockStartOffset, wordStartOffset, wordEndOffset) =>
              reported = (blockStartOffset, wordStartOffset, wordEndOffset),
        ),
      ),
    );

    await tester.tap(find.text("HOUSE "));
    await tester.pump();

    expect(reported, (headingBlock.startOffset, houseWord.startOffset, houseWord.endOffset));
  });

  testWidgets("the whole band around a word is clickable, not only its glyphs", (tester) async {
    await _useLargeSurface(tester);
    final layout = _buildLayout();
    final houseWord = layout.blocks.first.words[1];

    (int, int, int)? reported;
    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          layout: layout,
          onWordTapped: (blockStartOffset, wordStartOffset, wordEndOffset) =>
              reported = (blockStartOffset, wordStartOffset, wordEndOffset),
        ),
      ),
    );

    // The bottom-left corner of the word's own box: inside its padding, below the glyphs
    // themselves, and on the very edge of what the box covers.
    final box = tester.getRect(find.text("HOUSE "));
    await tester.tapAt(Offset(box.left + 1, box.bottom + 1));
    await tester.pump();

    expect(reported?.$2, houseWord.startOffset);
  });

  testWidgets("paints this shot's coverage stronger than another shot's, and the anchor apart", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    final layout = _buildLayout();
    final intWord = layout.blocks.first.words.first;
    final houseWord = layout.blocks.first.words[1];
    final dayWord = layout.blocks.first.words[3];

    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          layout: layout,
          ownRanges: [
            _buildRange(startOffset: houseWord.startOffset, endOffset: houseWord.endOffset),
          ],
          otherShotsRanges: {
            "1/2": [_buildRange(startOffset: dayWord.startOffset, endOffset: dayWord.endOffset)],
          },
          pendingAnchor: (
            blockStartOffset: layout.blocks.first.startOffset,
            wordStartOffset: intWord.startOffset,
            wordEndOffset: intWord.endOffset,
          ),
        ),
      ),
    );

    final anchor = _backgroundOfWord(tester, "INT. ");
    final own = _backgroundOfWord(tester, "HOUSE ");
    final other = _backgroundOfWord(tester, "DAY");
    final plain = _backgroundOfWord(tester, "- ");

    expect(anchor?.a, 1);
    expect(own?.a, greaterThan(other!.a));
    expect(plain, isNull);
  });

  testWidgets("a range's words are painted as one continuous band, whitespace included", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;

    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          layout: layout,
          ownRanges: [
            _buildRange(
              startOffset: headingBlock.words.first.startOffset,
              endOffset: headingBlock.words[1].endOffset,
            ),
          ],
        ),
      ),
    );

    final first = tester.getRect(find.text("INT. "));
    final second = tester.getRect(find.text("HOUSE "));

    // The two boxes touch: the space between the two words belongs to the first one's own box, so
    // the highlight reads as one band rather than two patches.
    expect(first.right, moreOrLessEquals(second.left, epsilon: 0.5));
    expect(_backgroundOfWord(tester, "INT. "), isNotNull);
    expect(_backgroundOfWord(tester, "HOUSE "), isNotNull);
  });

  testWidgets("names the other shots covering a block, under it", (tester) async {
    await _useLargeSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;

    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          layout: layout,
          otherShotsRanges: {
            "1/2": [
              _buildRange(startOffset: headingBlock.startOffset, endOffset: headingBlock.endOffset),
            ],
          },
        ),
      ),
    );

    expect(find.text("Also covered by 1/2"), findsOneWidget);
  });

  testWidgets("shows the hint matching the current click state", (tester) async {
    await _useLargeSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildDialog()));

    expect(
      find.text("Click a word to start a range; click a covered word to remove it."),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          pendingAnchor: (blockStartOffset: 0, wordStartOffset: 0, wordEndOffset: 4),
        ),
      ),
    );

    expect(find.text("Click another word of the same block to close the range."), findsOneWidget);
  });

  testWidgets("counts the covered words and the ranges, and reports Clear all", (tester) async {
    await _useLargeSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    final totalWords = layout.blocks.fold<int>(0, (sum, block) => sum + block.words.length);
    var cleared = false;

    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          layout: layout,
          ownRanges: [
            _buildRange(
              startOffset: headingBlock.startOffset,
              endOffset: headingBlock.words[1].endOffset,
            ),
          ],
          onClearAll: () => cleared = true,
        ),
      ),
    );

    expect(find.text("2 words covered of $totalWords · 1 range"), findsOneWidget);

    await tester.tap(find.text("Clear all"));
    await tester.pump();

    expect(cleared, isTrue);
  });
}
