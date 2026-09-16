// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_search.dart';

/// Wraps [child] in the app's own light theme — the sheet paints its backdrop from the
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

/// Gives the test surface room for a whole simulated page, restoring the default size once the test
/// ends.
Future<void> _useLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A single-scene screenplay: heading then one action line, matching the fixture
/// `OcptScriptWordLayout.of`'s own tests use elsewhere.
const _sceneId = "scene-1";
const _sceneText = "INT. HOUSE - DAY\n\nA lamp sits on the desk.\n";

/// The layout every test in this file reads its word offsets from — exactly what
/// `OcptBreakdownScriptView` builds internally from the same scene text.
final _layout = OcptScriptWordLayout.of(sceneId: _sceneId, sceneText: _sceneText);

/// The action block's own words: "A", "lamp", "sits", "on", "the", "desk.".
final _actionWords = _layout.blocks[1].words;

/// Builds the scene every test starts from, [tags] overriding its own live tags.
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

/// Builds a tag covering [word], pointing at target [targetId] of [targetKind].
OcptBreakdownTag _buildTag({
  required OcptScriptWord word,
  OcptBreakdownTargetKind targetKind = OcptBreakdownTargetKind.element,
  String targetId = "el-1",
  bool needsCheck = false,
}) => OcptBreakdownTag(
  id: "tag-${word.startOffset}",
  sceneId: _sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: word.startOffset,
  endOffset: word.endOffset,
  taggedText: word.text,
  needsCheck: needsCheck,
);

/// Builds an element target of [category] named [name].
OcptBreakdownTarget _buildElementTarget({
  String id = "el-1",
  String name = "Lamp",
  OcptElementCategory category = OcptElementCategory.prop,
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.element,
  id: id,
  name: name,
  category: category,
  status: OcptElementStatus.toFind,
  sceneIds: const [_sceneId],
  occurrenceCount: 1,
);

/// The `BoxDecoration` of the word rendered as [text]'s own click-target `Container`, or null when
/// it carries none (an untagged word). A word's own box carries the whitespace that follows it in
/// the source, so a word is found by the text it is rendered *with*, trailing space included.
BoxDecoration? _decorationOfWord(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return container.decoration as BoxDecoration?;
}

/// The width of the block box — the `SizedBox` that wraps a word's own text — the word rendered as
/// [text] sits in: what the compact phone layout scales down.
double _blockBoxWidthOf(WidgetTester tester, String text) => tester
    .widget<SizedBox>(find.ancestor(of: find.text(text), matching: find.byType(SizedBox)).first)
    .width!;

/// Wraps [child] in a phone-width `MediaQuery` so `ocptIsPhoneWidth` reads a phone — without
/// shrinking the render surface itself (which `setSurfaceSize` does, and the blown-up test glyph
/// metrics would then overflow): the feature keys off `MediaQuery.sizeOf`, so overriding its size
/// alone is what a phone looks like to it.
Widget _atPhoneWidth(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(size: const Size(375, 800)),
    child: child,
  ),
);

/// Builds the view with sensible defaults, only the fields a given test cares about overridden.
Widget _buildView({
  OcptBreakdownScene? scene,
  List<OcptBreakdownTarget> targets = const [],
  Set<OcptBreakdownLegendKey> hiddenLegendKeys = const {},
  OcptBreakdownSelectedTargetRef selectedTargetRef,
  void Function(OcptBreakdownTargetKind targetKind, String targetId, String sceneId)?
  onTargetSelected,
  void Function(String sceneId, int wordStartOffset, int wordEndOffset)? onWordClicked,
  bool isWordClickWithheld = false,
  OcptBreakdownPendingTagAnchor? pendingTagAnchor,
  OcptBreakdownPendingTagRange? pendingTagRange,
  List<OcptBreakdownSearchCandidate> candidates = const [],
  VoidCallback? onSelectionCancelled,
}) => OcptBreakdownScriptView(
  screenplayText: _sceneText,
  scenes: [scene ?? _buildScene()],
  targetById: ocptBreakdownTargetsById(targets),
  pageSetup: const OcptPageSetup.standard(),
  selectedSceneId: null,
  onSceneSelected: (_) {},
  hiddenLegendKeys: hiddenLegendKeys,
  selectedTargetRef: selectedTargetRef,
  onTargetSelected: onTargetSelected ?? (_, __, ___) {},
  onWordClicked: isWordClickWithheld ? null : (onWordClicked ?? (_, __, ___) {}),
  pendingTagAnchor: pendingTagAnchor,
  pendingTagRange: pendingTagRange,
  candidates: candidates,
  onSelectionCancelled: onSelectionCancelled ?? () {},
  onPopoverCancelled: () {},
  onPopoverTargetLinked: (_, __) {},
  onPopoverElementCreationRequested: (_, __) {},
  locations: const [],
  onPopoverSetCreationRequested: (_, __) {},
  onOpenInResourcesRequested: () {},
);

void main() {
  testWidgets("a tagged passage is washed with its target's own colour", (tester) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget();

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1])]),
          targets: [target],
        ),
      ),
    );

    // The placed tag hugs the word core, its trailing space left outside the wash.
    final color = _decorationOfWord(tester, "lamp")?.color;
    final expected = Color(target.color);
    expect(color, isNotNull);
    expect(color!.r, expected.r);
    expect(color.g, expected.g);
    expect(color.b, expected.b);
    // An untagged word of the same block stays plain.
    expect(_decorationOfWord(tester, "sits ")?.color, isNull);
  });

  testWidgets("a placed tag hugs the word core, dropping the punctuation it wears", (tester) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget(
      id: "el-desk",
      name: "Desk",
      category: OcptElementCategory.setDressing,
    );

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[5], targetId: "el-desk")]),
          targets: [target],
        ),
      ),
    );

    // "desk." is tagged: the wash hugs "desk", the full stop left outside it, so the placed tag
    // reads over the same passage the selection did — never one box over "desk.".
    expect(_decorationOfWord(tester, "desk")?.color, isNotNull);
    expect(find.text("desk."), findsNothing);
  });

  testWidgets("on a phone it scales the indents and box widths down by the compact factor", (
    tester,
  ) async {
    // A wide render surface both layouts share (the blown-up test glyph metrics need the room); the
    // phone/desktop difference is the MediaQuery width alone, exactly what the feature keys off.
    await _useLargeSurface(tester);

    // Desktop: the action block is laid out at its full screenplay box width.
    await tester.pumpWidget(_wrapInApp(_buildView()));
    final desktopWidth = _blockBoxWidthOf(tester, "lamp ");

    // Phone: the same block scales down by `OcptEditorPreviewLayout.compactLayoutScale`, leaving far
    // less left margin (the user's own report).
    await tester.pumpWidget(_wrapInApp(_atPhoneWidth(_buildView())));
    final phoneWidth = _blockBoxWidthOf(tester, "lamp ");

    expect(phoneWidth, lessThan(desktopWidth));
    expect(phoneWidth, closeTo(desktopWidth * OcptEditorPreviewLayout.compactLayoutScale, 0.5));
  });

  testWidgets("a hidden legend key stops painting its tagged words", (tester) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget();

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1])]),
          targets: [target],
          hiddenLegendKeys: {(OcptBreakdownTargetKind.element, OcptElementCategory.prop)},
        ),
      ),
    );

    expect(_decorationOfWord(tester, "lamp ")?.color, isNull);
  });

  testWidgets("the selected target's tagged words carry a ring", (tester) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget();

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1])]),
          targets: [target],
          selectedTargetRef: (OcptBreakdownTargetKind.element, target.id),
        ),
      ),
    );

    final decoration = _decorationOfWord(tester, "lamp");
    expect(decoration?.border, isNotNull);
  });

  testWidgets("only the selected target's own tag gets a ring, not another one's", (tester) async {
    await _useLargeSurface(tester);
    final lamp = _buildElementTarget();
    final desk = _buildElementTarget(id: "el-2", name: "Desk", category: OcptElementCategory.setDressing);

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(
            tags: [
              _buildTag(word: _actionWords[1]),
              _buildTag(word: _actionWords[5], targetId: "el-2"),
            ],
          ),
          targets: [lamp, desk],
          selectedTargetRef: (OcptBreakdownTargetKind.element, "el-1"),
        ),
      ),
    );

    expect(_decorationOfWord(tester, "lamp")?.border, isNotNull);
    expect(_decorationOfWord(tester, "desk")?.border, isNull);
  });

  testWidgets("a tag needing a check is underlined in the warning colour", (tester) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget();

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1], needsCheck: true)]),
          targets: [target],
        ),
      ),
    );

    final text = tester.widget<Text>(find.text("lamp"));
    expect(text.style?.decoration, TextDecoration.underline);
    expect(text.style?.decorationStyle, TextDecorationStyle.dashed);
  });

  testWidgets("a tag whose target has been dropped from the snapshot leaves the word plain", (
    tester,
  ) async {
    await _useLargeSurface(tester);

    // No target for "gone" is passed at all, mirroring `OcptBreakdownSnapshot.build`'s own case.
    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1], targetId: "gone")]),
        ),
      ),
    );

    expect(_decorationOfWord(tester, "lamp ")?.color, isNull);
    // Clicking it must not throw.
    await tester.tap(find.text("lamp "));
    await tester.pump();
  });

  testWidgets("clicking a tagged word reports its target and the scene it was clicked in", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget();
    (OcptBreakdownTargetKind, String, String)? reported;

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1])]),
          targets: [target],
          onTargetSelected: (kind, id, sceneId) => reported = (kind, id, sceneId),
        ),
      ),
    );

    await tester.tap(find.text("lamp"));
    await tester.pump();

    expect(reported, (OcptBreakdownTargetKind.element, target.id, _sceneId));
  });

  testWidgets("clicking a hidden tagged word still reports its target", (tester) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget();
    (OcptBreakdownTargetKind, String, String)? reported;

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1])]),
          targets: [target],
          hiddenLegendKeys: {(OcptBreakdownTargetKind.element, OcptElementCategory.prop)},
          onTargetSelected: (kind, id, sceneId) => reported = (kind, id, sceneId),
        ),
      ),
    );

    await tester.tap(find.text("lamp "));
    await tester.pump();

    expect(reported, (OcptBreakdownTargetKind.element, target.id, _sceneId));
  });

  testWidgets("clicking a plain word reports its own scene-relative offsets", (tester) async {
    await _useLargeSurface(tester);
    final sitsWord = _actionWords[2];
    (String, int, int)? reported;

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(onWordClicked: (sceneId, start, end) => reported = (sceneId, start, end)),
      ),
    );

    await tester.tap(find.text("sits "));
    await tester.pump();

    expect(reported, (_sceneId, sitsWord.startOffset, sitsWord.endOffset));
  });

  testWidgets("a plain word click is withheld while a version is previewed, its own tap doing nothing", (
    tester,
  ) async {
    await _useLargeSurface(tester);

    await tester.pumpWidget(_wrapInApp(_buildView(isWordClickWithheld: true)));

    // Must not throw: the word simply has no click callback at all.
    await tester.tap(find.text("sits "));
    await tester.pump();
  });

  testWidgets("a tagged word still selects its target while a version is previewed", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    final target = _buildElementTarget();
    (OcptBreakdownTargetKind, String, String)? reported;

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          scene: _buildScene(tags: [_buildTag(word: _actionWords[1])]),
          targets: [target],
          isWordClickWithheld: true,
          onTargetSelected: (kind, id, sceneId) => reported = (kind, id, sceneId),
        ),
      ),
    );

    await tester.tap(find.text("lamp"));
    await tester.pump();

    expect(reported, (OcptBreakdownTargetKind.element, target.id, _sceneId));
  });

  testWidgets("the pending anchor word is marked distinctly, not with a category colour", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    final anchorWord = _actionWords[1];

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagAnchor: (
            sceneId: _sceneId,
            wordStartOffset: anchorWord.startOffset,
            wordEndOffset: anchorWord.endOffset,
          ),
        ),
      ),
    );

    // The box hugs the word core — the accent fill, distinct from any category wash, and its
    // on-accent text — while the trailing space it carries stays outside it, so "lamp " is never one
    // box.
    final colorScheme = Theme.of(tester.element(find.text("lamp"))).colorScheme;
    final decoration = _decorationOfWord(tester, "lamp");
    expect(decoration?.color, colorScheme.primary);
    final text = tester.widget<Text>(find.text("lamp"));
    expect(text.style?.color, colorScheme.onPrimary);
    expect(find.text("lamp "), findsNothing);
  });

  testWidgets("a pending anchor trims the trailing punctuation off its own highlight", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    // "desk." is the action line's last word, a word wearing a full stop.
    final anchorWord = _actionWords[5];

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagAnchor: (
            sceneId: _sceneId,
            wordStartOffset: anchorWord.startOffset,
            wordEndOffset: anchorWord.endOffset,
          ),
        ),
      ),
    );

    final colorScheme = Theme.of(tester.element(find.text("desk"))).colorScheme;
    // The accent box hugs the word core alone.
    expect(_decorationOfWord(tester, "desk")?.color, colorScheme.primary);
    expect(tester.widget<Text>(find.text("desk")).style?.color, colorScheme.onPrimary);
    // The whole "desk." is never one box any more: the full stop sits outside the highlight, so no
    // single word box carries it.
    expect(find.text("desk."), findsNothing);
  });

  testWidgets("Escape abandons an open selection", (tester) async {
    await _useLargeSurface(tester);
    final anchorWord = _actionWords[1];
    var cancelled = false;

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagAnchor: (
            sceneId: _sceneId,
            wordStartOffset: anchorWord.startOffset,
            wordEndOffset: anchorWord.endOffset,
          ),
          onSelectionCancelled: () => cancelled = true,
        ),
      ),
    );
    // The view grabs its keyboard focus one frame after an open selection appears.
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelled, isTrue);
  });

  testWidgets("clicking the sheet away from any word abandons an open selection", (tester) async {
    await _useLargeSurface(tester);
    final anchorWord = _actionWords[1];
    var cancelled = false;

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagAnchor: (
            sceneId: _sceneId,
            wordStartOffset: anchorWord.startOffset,
            wordEndOffset: anchorWord.endOffset,
          ),
          onSelectionCancelled: () => cancelled = true,
        ),
      ),
    );

    // The top-left corner is the grey backdrop around the centred page — no word there.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(cancelled, isTrue);
  });

  testWidgets("the range stays highlighted while its popover is open", (tester) async {
    await _useLargeSurface(tester);
    final firstWord = _actionWords[1]; // lamp
    final lastWord = _actionWords[2]; // sits

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagRange: (
            sceneId: _sceneId,
            startOffset: firstWord.startOffset,
            endOffset: lastWord.endOffset,
            taggedText: "lamp sits",
            closingWordStartOffset: lastWord.startOffset,
            closingWordEndOffset: lastWord.endOffset,
          ),
        ),
      ),
    );

    final colorScheme = Theme.of(tester.element(find.text("lamp "))).colorScheme;
    // Both words wear the accent while the popover chooses what to tag them as: the first keeps its
    // bridging space (the band holds), the last hugs its core.
    expect(_decorationOfWord(tester, "lamp ")?.color, colorScheme.primary);
    expect(_decorationOfWord(tester, "sits")?.color, colorScheme.primary);
    expect(find.text("sits "), findsNothing);
  });

  testWidgets(
    "a word whose range with the pending anchor would overlap a live tag is not a click target",
    (tester) async {
      await _useLargeSurface(tester);
      // The live tag covers "sits" (word index 2); the anchor is "A" (word index 0).
      final scene = _buildScene(tags: [_buildTag(word: _actionWords[2])]);
      final target = _buildElementTarget();
      var wordClicked = false;

      await tester.pumpWidget(
        _wrapInApp(
          _buildView(
            scene: scene,
            targets: [target],
            pendingTagAnchor: (
              sceneId: _sceneId,
              wordStartOffset: _actionWords[0].startOffset,
              wordEndOffset: _actionWords[0].endOffset,
            ),
            onWordClicked: (_, __, ___) => wordClicked = true,
          ),
        ),
      );

      // "lamp" (index 1) closes before the tag starts: not blocked, still a click target.
      final lampStyle = tester.widget<Text>(find.text("lamp ")).style;
      expect(lampStyle?.color?.a, 1.0);

      // "on" (index 3) would close a range crossing the tag over "sits": blocked, greyed out and
      // not a click target at all.
      final onStyle = tester.widget<Text>(find.text("on ")).style;
      expect(onStyle?.color?.a, lessThan(1.0));

      await tester.tap(find.text("on "));
      await tester.pump();
      expect(wordClicked, isFalse);

      await tester.tap(find.text("lamp "));
      await tester.pump();
      expect(wordClicked, isTrue);
    },
  );

  testWidgets("a closed range opens the popover, anchored under the word that closed it", (
    tester,
  ) async {
    await _useLargeSurface(tester);
    final anchorWord = _actionWords[1];
    final closingWord = _actionWords[5];

    await tester.pumpWidget(
      _wrapInApp(
        _buildView(
          pendingTagRange: (
            sceneId: _sceneId,
            startOffset: anchorWord.startOffset,
            endOffset: closingWord.endOffset,
            taggedText: "lamp sits on the desk.",
            closingWordStartOffset: closingWord.startOffset,
            closingWordEndOffset: closingWord.endOffset,
          ),
        ),
      ),
    );

    expect(find.byType(OcptBreakdownTagPopoverAnchor), findsOneWidget);

    // The overlay entry is only revealed after the first post-frame callback.
    await tester.pump();

    expect(find.byType(OcptBreakdownTagPopover), findsOneWidget);
    expect(find.text('"lamp sits on the desk."'), findsOneWidget);
  });
}
