// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_editor.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

/// Grows the test surface tall enough that the whole panel is built and hit-testable without
/// having to scroll it, restoring the default size once the test ends.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A realistic scene: heading, an action line, a character cue, a parenthetical and a dialogue
/// line, matching the fixture `OcptShotCoverageLayout.of`'s own tests use.
const _sceneId = "scene-1";
const _sceneText =
    'INT. HOUSE - DAY\n\nJohn walks in.\n\nJOHN\n(whispering)\nHello there.';

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

/// Builds an editor with a sensible default of every field, only the fields a given test cares
/// about overridden.
Widget _buildEditor({
  OcptShotCoverageLayout? layout,
  List<OcptShotCoverageRange> ownRanges = const [],
  Map<String, List<OcptShotCoverageRange>> otherShotsRanges = const {},
  Set<String> staleRangeIds = const {},
  OcptShotCoverageAnchor? pendingAnchor,
  void Function(int blockStartOffset, int wordStartOffset, int wordEndOffset)? onWordTapped,
  VoidCallback? onClearAll,
}) => OcptShotCoverageEditor(
  layout: layout,
  ownRanges: ownRanges,
  otherShotsRanges: otherShotsRanges,
  staleRangeIds: staleRangeIds,
  pendingAnchor: pendingAnchor,
  onWordTapped: onWordTapped ?? (_, __, ___) {},
  onClearAll: onClearAll ?? () {},
);

/// The `InkWell` painting decoration of the word [text], found among every `Container` sharing
/// its ancestry with that text.
BoxDecoration? _decorationOfWord(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return container.decoration as BoxDecoration?;
}

void main() {
  testWidgets("shows the orphan hint when the layout is null", (tester) async {
    await tester.pumpWidget(_wrapInApp(_buildEditor()));

    expect(find.text("This shot's scene is gone: there is nothing left to cover."), findsOneWidget);
  });

  testWidgets("renders one block per non-blank source line, labelled by its Fountain line type",
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildEditor(layout: _buildLayout())));

    expect(find.text("SCENE HEADING"), findsOneWidget);
    expect(find.text("ACTION"), findsOneWidget);
    expect(find.text("CHARACTER"), findsOneWidget);
    expect(find.text("PARENTHETICAL"), findsOneWidget);
    expect(find.text("DIALOGUE"), findsOneWidget);
  });

  testWidgets("renders every block's words", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildEditor(layout: _buildLayout())));

    expect(find.text("INT."), findsOneWidget);
    expect(find.text("HOUSE"), findsOneWidget);
    expect(find.text("Hello"), findsOneWidget);
    expect(find.text("there."), findsOneWidget);
  });

  testWidgets("tapping a word reports its block start offset and its own offsets", (tester) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    final houseWord = headingBlock.words[1];

    (int, int, int)? reported;
    await tester.pumpWidget(
      _wrapInApp(
        _buildEditor(
          layout: layout,
          onWordTapped: (blockStartOffset, wordStartOffset, wordEndOffset) =>
              reported = (blockStartOffset, wordStartOffset, wordEndOffset),
        ),
      ),
    );

    await tester.tap(find.text("HOUSE"));
    await tester.pump();

    expect(reported, (headingBlock.startOffset, houseWord.startOffset, houseWord.endOffset));
  });

  testWidgets("a word covered by this shot and one covered by another shot are painted differently",
      (tester) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final houseWord = layout.blocks.first.words[1]; // "HOUSE"
    final dayWord = layout.blocks.first.words[3]; // "DAY"

    await tester.pumpWidget(
      _wrapInApp(
        _buildEditor(
          layout: layout,
          ownRanges: [
            _buildRange(startOffset: houseWord.startOffset, endOffset: houseWord.endOffset),
          ],
          otherShotsRanges: {
            "1/2": [_buildRange(startOffset: dayWord.startOffset, endOffset: dayWord.endOffset)],
          },
        ),
      ),
    );

    final ownColor = _decorationOfWord(tester, "HOUSE")?.color?.a;
    final otherColor = _decorationOfWord(tester, "DAY")?.color?.a;
    final neutralColor = _decorationOfWord(tester, "INT.")?.color;

    expect(ownColor, isNotNull);
    expect(otherColor, isNotNull);
    expect(ownColor, greaterThan(otherColor!));
    expect(neutralColor, isNull);
  });

  testWidgets("the also-covered-by line lists the other shots' codes", (tester) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;

    await tester.pumpWidget(
      _wrapInApp(
        _buildEditor(
          layout: layout,
          otherShotsRanges: {
            "1/2": [
              _buildRange(
                startOffset: headingBlock.startOffset,
                endOffset: headingBlock.endOffset,
              ),
            ],
            "1/4": [
              _buildRange(
                startOffset: headingBlock.startOffset,
                endOffset: headingBlock.endOffset,
              ),
            ],
          },
        ),
      ),
    );

    expect(find.text("Also covered by 1/2 · 1/4"), findsOneWidget);
  });

  testWidgets("the modified badge only shows on a block with a stale range of the selected shot",
      (tester) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    final actionBlock = layout.blocks[1];

    await tester.pumpWidget(
      _wrapInApp(
        _buildEditor(
          layout: layout,
          ownRanges: [
            _buildRange(
              id: "stale-range",
              startOffset: headingBlock.startOffset,
              endOffset: headingBlock.endOffset,
            ),
            _buildRange(
              id: "fresh-range",
              startOffset: actionBlock.startOffset,
              endOffset: actionBlock.endOffset,
            ),
          ],
          staleRangeIds: const {"stale-range"},
        ),
      ),
    );

    expect(find.text("Modified"), findsOneWidget);
  });

  testWidgets("the footer counts covered words without double-counting overlaps", (tester) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    final totalWords = layout.blocks.fold<int>(0, (sum, block) => sum + block.words.length);

    await tester.pumpWidget(
      _wrapInApp(
        _buildEditor(
          layout: layout,
          ownRanges: [
            _buildRange(
              startOffset: headingBlock.startOffset,
              endOffset: headingBlock.words[1].endOffset,
            ),
          ],
        ),
      ),
    );

    expect(find.text("2 words covered of $totalWords · 1 range"), findsOneWidget);
  });

  testWidgets("shows the no-anchor hint while no range is being drawn", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildEditor(layout: _buildLayout())));

    expect(
      find.text("Click a word to start a range; click a covered word to remove it."),
      findsOneWidget,
    );
  });

  testWidgets("shows the pending-anchor hint while a range's first word is already clicked",
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildEditor(
          layout: _buildLayout(),
          pendingAnchor: (blockStartOffset: 0, wordStartOffset: 0, wordEndOffset: 4),
        ),
      ),
    );

    expect(
      find.text("Click another word of the same block to close the range."),
      findsOneWidget,
    );
  });

  testWidgets("clicking Clear all reports it", (tester) async {
    await _useTallSurface(tester);
    var cleared = false;

    await tester.pumpWidget(
      _wrapInApp(_buildEditor(layout: _buildLayout(), onClearAll: () => cleared = true)),
    );

    await tester.tap(find.text("Clear all"));
    await tester.pump();

    expect(cleared, isTrue);
  });
}
