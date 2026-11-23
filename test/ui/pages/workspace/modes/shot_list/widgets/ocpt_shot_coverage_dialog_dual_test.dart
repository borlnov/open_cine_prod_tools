// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_dialog.dart';

/// The scene every test reads: ROSS and KIM side by side, the caret apart from KIM's name.
const _sceneText =
    "INT. HOUSE - DAY\n\nROSS\nFirst line here.\nAnd more.\n\nKIM ^\nSecond line there.";

/// The layout of [_sceneText].
final _layout = OcptScriptWordLayout.of(sceneId: "scene-1", sceneText: _sceneText);

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

/// Build a range of the scene.
OcptShotCoverageRange _buildRange(int startOffset, int endOffset) => OcptShotCoverageRange(
  id: "range-$startOffset",
  sceneId: "scene-1",
  startOffset: startOffset,
  endOffset: endOffset,
  coveredTextDigest: "irrelevant-for-this-test",
  isStale: false,
);

/// Build the dialog over [_layout].
Widget _buildDialog({
  List<OcptShotCoverageRange> ownRanges = const [],
  Map<String, List<OcptShotCoverageRange>> otherShotsRanges = const {},
  void Function(int wordStartOffset, int wordEndOffset)? onWordTapped,
}) => OcptShotCoverageDialog(
  shotCode: "1/3",
  sequenceHeading: "INT. HOUSE - DAY",
  layout: _layout,
  pageSetup: const OcptPageSetup.standard(),
  ownRanges: ownRanges,
  otherShotsRanges: otherShotsRanges,
  pendingAnchor: null,
  onWordTapped: onWordTapped ?? (_, __) {},
  onClearAll: () {},
  onAnchorCancelled: () {},
);

/// Get the background colour of the click box of the word rendered as [text].
Color? _backgroundOf(WidgetTester tester, String text) => tester
    .widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)).first)
    .color;

/// A router manager that records nothing: the dialog is pumped without a route.
class _SilentRouterManager extends OcptRouterManager {
  /// Do nothing, there is no route to pop.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// Run the tests of [OcptShotCoverageDialog] over a dual-dialogue pair.
void main() {
  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    managers.registerSingleton<OcptRouterManager>(_SilentRouterManager());
  });

  /// Give the test surface room for a whole page.
  Future<void> useLargeSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets("sets the two speeches side by side, the caret hidden", (tester) async {
    await useLargeSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildDialog()));

    final ross = tester.getTopLeft(find.text("ROSS"));
    final kim = tester.getTopLeft(find.text("KIM "));
    final leftLine = tester.getTopLeft(find.text("First "));
    final rightLine = tester.getTopLeft(find.text("Second "));

    expect(kim.dy, ross.dy);
    expect(kim.dx, greaterThan(leftLine.dx + 100));
    expect(rightLine.dy, leftLine.dy);
    expect(find.textContaining("^", findRichText: true), findsNothing);
  });

  testWidgets("reports a click on a word of each column", (tester) async {
    await useLargeSurface(tester);
    final clicks = <(int, int)>[];
    await tester.pumpWidget(
      _wrapInApp(_buildDialog(onWordTapped: (start, end) => clicks.add((start, end)))),
    );

    await tester.tap(find.text("First "));
    await tester.tap(find.text("Second "));

    final first = _layout.blocks[2].words[0];
    final second = _layout.blocks[5].words[0];
    expect(clicks, [(first.startOffset, first.endOffset), (second.startOffset, second.endOffset)]);
  });

  testWidgets("keeps the also covered caption under its block, in its column", (tester) async {
    await useLargeSurface(tester);
    final right = _layout.blocks[5];
    await tester.pumpWidget(
      _wrapInApp(
        _buildDialog(
          otherShotsRanges: {
            "1/2": [_buildRange(right.startOffset, right.endOffset)],
          },
        ),
      ),
    );

    final caption = tester.getTopLeft(find.text("Also covered by 1/2"));
    final rightLine = tester.getBottomLeft(find.text("there."));

    expect(caption.dx, tester.getTopLeft(find.text("Second ")).dx);
    expect(caption.dy, greaterThanOrEqualTo(rightLine.dy));
  });

  testWidgets("washes a range running from the left column into the right one", (tester) async {
    await useLargeSurface(tester);
    final from = _layout.blocks[3].words[0]; // "And"
    final to = _layout.blocks[5].words[0]; // "Second"
    await tester.pumpWidget(
      _wrapInApp(_buildDialog(ownRanges: [_buildRange(from.startOffset, to.endOffset)])),
    );

    expect(_backgroundOf(tester, "First "), isNull);
    expect(_backgroundOf(tester, "And "), isNotNull);
    expect(_backgroundOf(tester, "KIM "), isNotNull);
    expect(_backgroundOf(tester, "Second "), isNotNull);
    expect(_backgroundOf(tester, "there."), isNull);
  });

  testWidgets("does not count the lone caret of a cue among the words", (tester) async {
    await useLargeSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(_buildDialog(ownRanges: [_buildRange(0, _sceneText.length)])),
    );

    // Heading 4, ROSS 1, left speech 5, KIM 1, right speech 3: the caret is no word.
    expect(find.textContaining("14 words covered of 14"), findsOneWidget);
  });
}
