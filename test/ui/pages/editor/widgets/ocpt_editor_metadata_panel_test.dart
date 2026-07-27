// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_metadata_panel.dart';

/// A source range every hand-built entry in this file shares: the panel never looks at it.
const _range = FountainSourceRange(startLine: 0, endLine: 0, startOffset: 0, endOffset: 0);

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, constrained
/// to [width], matching `ocpt_editor_inspector_panel_test.dart`'s own helper.
Widget _wrap(Widget child, {double width = 220}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: width, child: child)),
);

FountainTitlePageEntry _entry(String key, String value) =>
    FountainTitlePageEntry(key: key, values: [value], sourceRange: _range);

/// Grows the test surface well past the panel's content height, so the "Edit…" button at the
/// bottom of the (non-lazy, so already fully built) `ListView` is actually hit-testable; matches
/// `ocpt_editor_syntax_guide_panel_test.dart`'s own `_growTestSurface` idiom.
void _growTestSurface(WidgetTester tester, {double height = 1200}) {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('renders every title-page field and the script statistics', (tester) async {
    final fullTitlePage = FountainTitlePage(
      entries: [
        _entry('Title', 'Les Sentiers de Verre'),
        _entry('Credit', 'written by'),
        _entry('Author', 'Léa Dubois'),
        _entry('Source', 'Original screenplay'),
        _entry('Draft date', '2026-07-27'),
        _entry('Contact', 'lea@example.com'),
      ],
      sourceRange: _range,
    );
    const statistics = FountainScriptStatistics(
      pageCount: 42,
      sceneCount: 10,
      speakingCharacterCount: 6,
      wordCount: 8640,
      signCount: 32000,
    );

    await tester.pumpWidget(
      _wrap(
        OcptEditorMetadataPanel(titlePage: fullTitlePage, statistics: statistics, onEditTitlePage: () {}),
        width: 400,
      ),
    );

    final context = tester.element(find.byType(OcptEditorMetadataPanel));
    final tr = Tr.of(context);

    expect(find.text('Les Sentiers de Verre'), findsOneWidget);
    expect(find.text('written by'), findsOneWidget);
    expect(find.text('Léa Dubois'), findsOneWidget);
    expect(find.text('Original screenplay'), findsOneWidget);
    expect(find.text('2026-07-27'), findsOneWidget);
    expect(find.text('lea@example.com'), findsOneWidget);

    expect(find.text(tr.editorStatsPages(42)), findsOneWidget);
    expect(find.text(tr.editorStatsScenes(10)), findsOneWidget);
    expect(find.text(tr.editorStatsCharacters(6)), findsOneWidget);
    expect(find.text(tr.editorStatsWords(8640)), findsOneWidget);
    expect(find.text(tr.editorStatsSigns(32000)), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing title page shows a dash for every field, not an empty row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OcptEditorMetadataPanel(
          titlePage: null,
          statistics: FountainScriptStatistics.empty,
          onEditTitlePage: () {},
        ),
      ),
    );

    // Title, Credit, Author, Source, Draft date, Contact: six dashes, one per field.
    expect(find.text('—'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Author field falls back to the "Authors" spelling', (tester) async {
    final titlePage = FountainTitlePage(
      entries: [_entry('Authors', 'Léa Dubois and Marc Petit')],
      sourceRange: _range,
    );

    await tester.pumpWidget(
      _wrap(
        OcptEditorMetadataPanel(
          titlePage: titlePage,
          statistics: FountainScriptStatistics.empty,
          onEditTitlePage: () {},
        ),
      ),
    );

    expect(find.text('Léa Dubois and Marc Petit'), findsOneWidget);
  });

  testWidgets('the Edit button opens the title-page dialog', (tester) async {
    _growTestSurface(tester);
    var editRequested = false;

    await tester.pumpWidget(
      _wrap(
        OcptEditorMetadataPanel(
          titlePage: null,
          statistics: FountainScriptStatistics.empty,
          onEditTitlePage: () => editRequested = true,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptEditorMetadataPanel));
    await tester.tap(find.text(Tr.of(context).editorMetadataEditTitlePageButtonLabel));

    expect(editRequested, isTrue);
  });

  testWidgets('does not overflow at the dock practical minimum width', (tester) async {
    final titlePage = FountainTitlePage(
      entries: [
        _entry('Title', 'A Very Long Title That Might Not Fit On One Line Easily'),
      ],
      sourceRange: _range,
    );

    await tester.pumpWidget(
      _wrap(
        OcptEditorMetadataPanel(
          titlePage: titlePage,
          statistics: const FountainScriptStatistics(
            pageCount: 142,
            sceneCount: 87,
            speakingCharacterCount: 23,
            wordCount: 24000,
            signCount: 96000,
          ),
          onEditTitlePage: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
