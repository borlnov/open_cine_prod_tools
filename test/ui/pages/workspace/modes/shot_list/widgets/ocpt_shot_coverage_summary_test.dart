// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_summary.dart';

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

/// Grows the test surface tall enough that the whole section is built and hit-testable without
/// having to scroll it, restoring the default size once the test ends.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 1200));
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

/// Builds a summary with a sensible default of every field, only the fields a given test cares
/// about overridden.
Widget _buildSummary({
  OcptShotCoverageLayout? layout,
  List<OcptShotCoverageRange> ownRanges = const [],
  Map<String, List<OcptShotCoverageRange>> otherShotsRanges = const {},
  Set<String> staleRangeIds = const {},
  VoidCallback? onSelectRequested,
  VoidCallback? onClearAll,
}) => OcptShotCoverageSummary(
  layout: layout,
  ownRanges: ownRanges,
  otherShotsRanges: otherShotsRanges,
  staleRangeIds: staleRangeIds,
  onSelectRequested: onSelectRequested ?? () {},
  onClearAll: onClearAll ?? () {},
);

void main() {
  testWidgets("shows the orphan hint, and no select button, when the layout is null", (
    tester,
  ) async {
    await tester.pumpWidget(_wrapInApp(_buildSummary()));

    expect(find.text("This shot's scene is gone: there is nothing left to cover."), findsOneWidget);
    expect(find.text("Select…"), findsNothing);
  });

  testWidgets("shows the empty hint while the shot covers nothing yet", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildSummary(layout: _buildLayout())));

    expect(find.text("No screenplay text covered yet."), findsOneWidget);
    expect(find.text("Select…"), findsOneWidget);
  });

  testWidgets("clicking Select… reports it", (tester) async {
    await _useTallSurface(tester);
    var requested = false;

    await tester.pumpWidget(
      _wrapInApp(_buildSummary(layout: _buildLayout(), onSelectRequested: () => requested = true)),
    );

    await tester.tap(find.text("Select…"));
    await tester.pump();

    expect(requested, isTrue);
  });

  testWidgets("quotes every covered extract, labelled by its block's Fountain line type", (
    tester,
  ) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final dialogueBlock = layout.blocks.last;

    await tester.pumpWidget(
      _wrapInApp(
        _buildSummary(
          layout: layout,
          ownRanges: [
            _buildRange(
              startOffset: dialogueBlock.startOffset,
              endOffset: dialogueBlock.words.first.endOffset,
            ),
          ],
        ),
      ),
    );

    expect(find.text("DIALOGUE"), findsOneWidget);
    expect(find.text("« Hello »"), findsOneWidget);
  });

  testWidgets("lists the extracts in the order they read in the scene, not the recorded order", (
    tester,
  ) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    final dialogueBlock = layout.blocks.last;

    await tester.pumpWidget(
      _wrapInApp(
        _buildSummary(
          layout: layout,
          ownRanges: [
            _buildRange(
              id: "later",
              startOffset: dialogueBlock.startOffset,
              endOffset: dialogueBlock.words.first.endOffset,
            ),
            _buildRange(
              id: "earlier",
              startOffset: headingBlock.startOffset,
              endOffset: headingBlock.words.first.endOffset,
            ),
          ],
        ),
      ),
    );

    final headingExtract = tester.getTopLeft(find.text("« INT. »")).dy;
    final dialogueExtract = tester.getTopLeft(find.text("« Hello »")).dy;

    expect(headingExtract, lessThan(dialogueExtract));
  });

  testWidgets("names the other shots covering the same extract", (tester) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;

    await tester.pumpWidget(
      _wrapInApp(
        _buildSummary(
          layout: layout,
          ownRanges: [
            _buildRange(startOffset: headingBlock.startOffset, endOffset: headingBlock.endOffset),
          ],
          otherShotsRanges: {
            "1/2": [
              _buildRange(startOffset: headingBlock.startOffset, endOffset: headingBlock.endOffset),
            ],
            "1/4": [
              _buildRange(startOffset: headingBlock.startOffset, endOffset: headingBlock.endOffset),
            ],
          },
        ),
      ),
    );

    expect(find.text("Also covered by 1/2 · 1/4"), findsOneWidget);
  });

  testWidgets("the modified badge only shows on a stale extract", (tester) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    final actionBlock = layout.blocks[1];

    await tester.pumpWidget(
      _wrapInApp(
        _buildSummary(
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
        _buildSummary(
          layout: layout,
          ownRanges: [
            _buildRange(
              id: "first",
              startOffset: headingBlock.startOffset,
              endOffset: headingBlock.words[1].endOffset,
            ),
            _buildRange(
              id: "overlapping",
              startOffset: headingBlock.words[1].startOffset,
              endOffset: headingBlock.words[1].endOffset,
            ),
          ],
        ),
      ),
    );

    expect(find.text("2 words covered of $totalWords · 2 ranges"), findsOneWidget);
  });

  testWidgets("Clear all is only offered once something is covered, and reports its click", (
    tester,
  ) async {
    await _useTallSurface(tester);
    final layout = _buildLayout();
    final headingBlock = layout.blocks.first;
    var cleared = false;

    await tester.pumpWidget(_wrapInApp(_buildSummary(layout: layout)));
    expect(find.text("Clear all"), findsNothing);

    await tester.pumpWidget(
      _wrapInApp(
        _buildSummary(
          layout: layout,
          ownRanges: [
            _buildRange(startOffset: headingBlock.startOffset, endOffset: headingBlock.endOffset),
          ],
          onClearAll: () => cleared = true,
        ),
      ),
    );

    await tester.tap(find.text("Clear all"));
    await tester.pump();

    expect(cleared, isTrue);
  });
}
