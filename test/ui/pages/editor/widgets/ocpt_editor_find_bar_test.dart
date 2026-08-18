// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, matching
/// `editor_page_test.dart`'s own `_wrapWithLocalization` helper.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// Builds a bar with every callback wired into [calls], appending the callback's own name (and,
/// for the value-carrying ones, the value it was called with) so a test can assert exactly which
/// one fired.
OcptEditorFindBar _buildBar({
  required List<String> calls,
  String query = "",
  String replacement = "",
  bool isCaseSensitive = false,
  bool isWholeWord = false,
  bool isReplaceRowOpen = false,
  int matchCount = 0,
  int? currentMatchIndex,
  int focusRequestId = 0,
  bool isReplaceOffered = true,
}) => OcptEditorFindBar(
  query: query,
  replacement: replacement,
  isCaseSensitive: isCaseSensitive,
  isWholeWord: isWholeWord,
  isReplaceRowOpen: isReplaceRowOpen,
  matchCount: matchCount,
  currentMatchIndex: currentMatchIndex,
  focusRequestId: focusRequestId,
  onQueryChanged: (query) => calls.add("onQueryChanged:$query"),
  onReplacementChanged: (replacement) => calls.add("onReplacementChanged:$replacement"),
  onCaseSensitivityToggled: () => calls.add("onCaseSensitivityToggled"),
  onWholeWordToggled: () => calls.add("onWholeWordToggled"),
  onNextRequested: () => calls.add("onNextRequested"),
  onPreviousRequested: () => calls.add("onPreviousRequested"),
  onReplaceRowToggled: () => calls.add("onReplaceRowToggled"),
  onReplaceRequested: isReplaceOffered ? () => calls.add("onReplaceRequested") : null,
  onReplaceAllRequested: isReplaceOffered ? () => calls.add("onReplaceAllRequested") : null,
  onCloseRequested: () => calls.add("onCloseRequested"),
);

void main() {
  testWidgets("the replace row is folded by default and unfolds on isReplaceRowOpen", (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(_wrapWithLocalization(_buildBar(calls: calls)));
    expect(find.text("Replace"), findsNothing);

    await tester.pumpWidget(
      _wrapWithLocalization(_buildBar(calls: calls, isReplaceRowOpen: true)),
    );
    expect(find.text("Replace"), findsOneWidget);
    expect(find.text("Replace all"), findsOneWidget);
  });

  testWidgets("the chevron reports onReplaceRowToggled", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrapWithLocalization(_buildBar(calls: calls)));

    await tester.tap(find.byTooltip("Show or hide replace"));
    expect(calls, contains("onReplaceRowToggled"));
  });

  testWidgets("typing in the find field reports onQueryChanged", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrapWithLocalization(_buildBar(calls: calls)));

    await tester.enterText(find.byType(TextField).first, "MARIE");

    expect(calls, contains("onQueryChanged:MARIE"));
  });

  testWidgets("typing in the replace field reports onReplacementChanged", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _wrapWithLocalization(_buildBar(calls: calls, isReplaceRowOpen: true)),
    );

    await tester.enterText(find.byType(TextField).last, "JEANNE");

    expect(calls, contains("onReplacementChanged:JEANNE"));
  });

  testWidgets("the Aa and ab toggles report onCaseSensitivityToggled/onWholeWordToggled", (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrapWithLocalization(_buildBar(calls: calls)));

    await tester.tap(find.byTooltip("Match case"));
    await tester.tap(find.byTooltip("Whole word"));

    expect(calls, containsAll(["onCaseSensitivityToggled", "onWholeWordToggled"]));
  });

  testWidgets("previous/next/close report their own callbacks", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _wrapWithLocalization(_buildBar(calls: calls, query: "MARIE", matchCount: 3)),
    );

    await tester.tap(find.byTooltip("Previous match"));
    await tester.tap(find.byTooltip("Next match"));
    await tester.tap(find.byTooltip("Close find and replace"));

    expect(
      calls,
      containsAll(["onPreviousRequested", "onNextRequested", "onCloseRequested"]),
    );
  });

  testWidgets("previous/next are disabled while there is no match", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _wrapWithLocalization(_buildBar(calls: calls, query: "MARIE")),
    );

    final previousButton = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip("Previous match"), matching: find.byType(IconButton)),
    );
    final nextButton = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip("Next match"), matching: find.byType(IconButton)),
    );

    expect(previousButton.onPressed, isNull);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets("Replace and Replace all report their own callbacks when matches exist", (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _wrapWithLocalization(
        _buildBar(calls: calls, query: "MARIE", matchCount: 2, isReplaceRowOpen: true),
      ),
    );

    await tester.tap(find.text("Replace"));
    await tester.tap(find.text("Replace all"));

    expect(calls, containsAll(["onReplaceRequested", "onReplaceAllRequested"]));
  });

  testWidgets("Replace and Replace all are withheld (disabled) when their callback is null", (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _wrapWithLocalization(
        _buildBar(
          calls: calls,
          query: "MARIE",
          matchCount: 2,
          isReplaceRowOpen: true,
          isReplaceOffered: false,
        ),
      ),
    );

    final replaceButton = tester.widget<TextButton>(
      find.ancestor(of: find.text("Replace"), matching: find.byType(TextButton)),
    );
    final replaceAllButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text("Replace all"), matching: find.byType(FilledButton)),
    );

    expect(replaceButton.onPressed, isNull);
    expect(replaceAllButton.onPressed, isNull);
  });

  testWidgets("shows the n/total counter, or a no-matches hint once the query is non-empty", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        _buildBar(calls: [], query: "MARIE", matchCount: 3, currentMatchIndex: 1),
      ),
    );
    expect(find.text("2/3"), findsOneWidget);

    await tester.pumpWidget(
      _wrapWithLocalization(_buildBar(calls: [], query: "ZZZ")),
    );
    expect(find.text("No matches"), findsOneWidget);

    await tester.pumpWidget(_wrapWithLocalization(_buildBar(calls: [])));
    expect(find.text("No matches"), findsNothing);
  });

  testWidgets("bumping focusRequestId (re)focuses and selects the find field", (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(_buildBar(calls: [], query: "MARIE", focusRequestId: 1)),
    );
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.focusNode?.hasFocus, isTrue);

    final controllerSelection = textField.controller!.selection;
    expect(controllerSelection.baseOffset, 0);
    expect(controllerSelection.extentOffset, "MARIE".length);
  });
}
