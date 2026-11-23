// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover.dart';

/// The scene every test reads: a dual-dialogue pair with a parenthetical on the left.
const _sceneId = "scene-1";

/// A heading, then ROSS and KIM^ side by side.
const _sceneText =
    "INT. HOUSE - DAY\n\nROSS\nFirst line here.\nAnd more.\n\nKIM^\nSecond line there.";

/// The layout of [_sceneText], the source of the word offsets the tests click.
final _layout = OcptScriptWordLayout.of(sceneId: _sceneId, sceneText: _sceneText);

/// The words of the left dialogue: "First", "line", "here.".
final _leftWords = _layout.blocks[2].words;

/// The words of the right cue: "KIM^" (the caret is part of the word).
final _rightCueWords = _layout.blocks[4].words;

/// The words of the right dialogue: "Second", "line", "there.".
final _rightWords = _layout.blocks[5].words;

/// Wrap [child] in the app's light theme and its localization delegates.
Widget _wrapInApp(Widget child) => MaterialApp(
  theme: ocpt_theme.ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// Give the test surface room for a whole page, restoring the default size once the test ends.
Future<void> _useLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Wrap [child] in a phone-width `MediaQuery`, without shrinking the render surface.
Widget _atPhoneWidth(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(size: const Size(375, 800)),
    child: child,
  ),
);

/// Build the scene, [tags] being its live tags.
OcptBreakdownScene _buildScene({List<OcptBreakdownTag> tags = const []}) => OcptBreakdownScene(
  id: _sceneId,
  position: 0,
  heading: "INT. HOUSE - DAY",
  sceneNumber: null,
  charStart: 0,
  charEnd: _sceneText.length,
  status: OcptBreakdownSceneStatus.toDo,
  notes: "",
  tags: tags,
  episodeNumber: null,
);

/// Build a tag covering [word].
OcptBreakdownTag _buildTag(OcptScriptWord word) => OcptBreakdownTag(
  id: "tag-${word.startOffset}",
  sceneId: _sceneId,
  targetKind: OcptBreakdownTargetKind.element,
  targetId: "el-1",
  startOffset: word.startOffset,
  endOffset: word.endOffset,
  taggedText: word.text,
  needsCheck: false,
);

/// Build the one element target the tags point at.
OcptBreakdownTarget _buildTarget() => const OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.element,
  id: "el-1",
  name: "Lamp",
  category: OcptElementCategory.prop,
  status: OcptElementStatus.toFind,
  sceneIds: [_sceneId],
  occurrenceCount: 1,
);

/// Build the view over [_sceneText].
Widget _buildView({
  OcptBreakdownScene? scene,
  List<OcptBreakdownTarget> targets = const [],
  void Function(String sceneId, int wordStartOffset, int wordEndOffset)? onWordClicked,
  OcptBreakdownPendingTagAnchor? pendingTagAnchor,
  OcptBreakdownPendingTagRange? pendingTagRange,
}) => OcptBreakdownScriptView(
  screenplayText: _sceneText,
  scenes: [scene ?? _buildScene()],
  targetById: ocptBreakdownTargetsById(targets),
  pageSetup: const OcptPageSetup.standard(),
  selectedSceneId: null,
  onSceneSelected: (_) {},
  hiddenLegendKeys: const {},
  selectedTargetRef: null,
  onTargetSelected: (_, __, ___) {},
  onWordClicked: onWordClicked ?? (_, __, ___) {},
  pendingTagAnchor: pendingTagAnchor,
  pendingTagRange: pendingTagRange,
  candidates: const [],
  onSelectionCancelled: () {},
  onPopoverCancelled: () {},
  onPopoverTargetLinked: (_, __) {},
  onPopoverElementCreationRequested: (_, __) {},
  locations: const [],
  onPopoverSetCreationRequested: (_, __) {},
  onOpenInResourcesRequested: () {},
);

/// Get the background colour of the click box of the word rendered as [text].
Color? _backgroundOf(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

/// Run the tests of [OcptBreakdownScriptView] over a dual-dialogue pair.
void main() {
  testWidgets("sets the two speeches side by side, from the same top", (tester) async {
    await _useLargeSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildView()));

    final ross = tester.getTopLeft(find.text("ROSS"));
    final kim = tester.getTopLeft(find.text("KIM"));
    final leftLine = tester.getTopLeft(find.text("First "));
    final rightLine = tester.getTopLeft(find.text("Second "));

    expect(kim.dy, ross.dy);
    expect(kim.dx, greaterThan(leftLine.dx + 100));
    expect(rightLine.dy, leftLine.dy);
    // The caret of the cue is no longer printed when the speech is set beside another.
    expect(find.textContaining("^", findRichText: true), findsNothing);
  });

  testWidgets("is as tall as its taller column, with no gap before the right cue", (tester) async {
    await _useLargeSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildView()));

    final leftBottom = tester.getBottomLeft(find.text("more.")).dy;
    final rightBottom = tester.getBottomLeft(find.text("there.")).dy;

    // The left column holds an extra line, so it decides the pair's height.
    expect(leftBottom, greaterThan(rightBottom));
    final paperBottom = tester.getBottomLeft(_paper(tester)).dy;
    expect(paperBottom, greaterThan(leftBottom));
  });

  testWidgets("reports a click on a word of each column", (tester) async {
    await _useLargeSurface(tester);
    final clicks = <(int, int)>[];
    await tester.pumpWidget(
      _wrapInApp(_buildView(onWordClicked: (_, start, end) => clicks.add((start, end)))),
    );

    await tester.tap(find.text("First "));
    await tester.tap(find.text("Second "));

    expect(clicks, [
      (_leftWords[0].startOffset, _leftWords[0].endOffset),
      (_rightWords[0].startOffset, _rightWords[0].endOffset),
    ]);
  });

  testWidgets("highlights the end of the left column and the start of the right for a range", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagRange: (
            sceneId: _sceneId,
            startOffset: _leftWords[1].startOffset,
            endOffset: _rightWords[0].endOffset,
            taggedText: "line here. And more. KIM^ Second",
            closingWordStartOffset: _rightWords[0].startOffset,
            closingWordEndOffset: _rightWords[0].endOffset,
          ),
        ),
      ),
    );

    final accent = Theme.of(tester.element(find.text("ROSS"))).colorScheme.primary;
    expect(_backgroundOf(tester, "First "), isNull);
    expect(_backgroundOf(tester, "line "), accent);
    expect(_backgroundOf(tester, "more."), accent);
    expect(_backgroundOf(tester, "KIM"), accent);
    expect(_backgroundOf(tester, "Second"), accent);
    expect(_backgroundOf(tester, "line "), accent);
    expect(_backgroundOf(tester, "there."), isNull);
  });

  testWidgets("greys the words of the right column an anchor on the left cannot reach", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    var clicked = false;
    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(_rightCueWords[0])]),
          targets: [_buildTarget()],
          pendingTagAnchor: (
            sceneId: _sceneId,
            wordStartOffset: _leftWords[0].startOffset,
            wordEndOffset: _leftWords[0].endOffset,
          ),
          onWordClicked: (_, __, ___) => clicked = true,
        ),
      ),
    );

    // The right cue is tagged: a range from the left anchor to anything after it would cross it.
    expect(tester.widget<Text>(find.text("Second ")).style?.color?.a, lessThan(1.0));
    expect(tester.widget<Text>(find.text("line ").last).style?.color?.a, lessThan(1.0));
    // Words of the left column before the tag stay clickable.
    expect(tester.widget<Text>(find.text("line ").first).style?.color?.a, 1.0);

    await tester.tap(find.text("Second "));
    expect(clicked, isFalse);
  });

  testWidgets("keeps the tag popover of a right-column word on screen", (tester) async {
    await _useLargeSurface(tester);
    final closing = _rightWords[2];
    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagRange: (
            sceneId: _sceneId,
            startOffset: _rightWords[0].startOffset,
            endOffset: closing.endOffset,
            taggedText: "Second line there.",
            closingWordStartOffset: closing.startOffset,
            closingWordEndOffset: closing.endOffset,
          ),
        ),
      ),
    );
    await tester.pump();

    final popover = tester.getRect(find.byType(OcptBreakdownTagPopover));
    expect(const Rect.fromLTWH(0, 0, 1400, 1400).contains(popover.topLeft), isTrue);
    expect(const Rect.fromLTWH(0, 0, 1400, 1400).contains(popover.bottomRight), isTrue);
  });

  testWidgets("stacks the pair on a phone and shows the caret, dimmed, after the name", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    await tester.pumpWidget(_wrapInApp(_atPhoneWidth(_buildView())));

    final leftBottom = tester.getBottomLeft(find.text("more.")).dy;
    final kim = tester.getTopLeft(find.text("KIM"));

    expect(kim.dy, greaterThanOrEqualTo(leftBottom));
    final caret = find.textContaining("^", findRichText: true);
    expect(caret, findsOneWidget);
    final span = tester.widget<RichText>(caret).text.toPlainText();
    expect(span, contains("^"));
  });
}

/// Find the sheet's white paper.
Finder _paper(WidgetTester tester) =>
    find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Material)).first;
