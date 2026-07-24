// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_fountain_syntax_entry.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_syntax_guide_panel.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, matching
/// `editor_page_test.dart`'s own `_wrapWithLocalization` helper. When [height] is given, the
/// panel is constrained to it (used by the small-height overflow test).
Widget _wrapWithLocalization(Widget child, {double? height}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: height == null ? child : SizedBox(height: height, child: child),
  ),
);

/// Grows the test surface well past the panel's full content height, so a `ListView` (which,
/// like `ListView.builder`, only materializes children near its viewport) actually builds every
/// entry instead of virtualizing the ones that would otherwise sit off-screen; matches
/// `ocpt_editor_status_bar_test.dart`'s own `_widenTestSurface` idiom.
void _growTestSurface(WidgetTester tester, {double height = 3000}) {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets("renders all 4 section headers", (tester) async {
    _growTestSurface(tester);
    await tester.pumpWidget(_wrapWithLocalization(const OcptEditorSyntaxGuidePanel()));

    final context = tester.element(find.byType(OcptEditorSyntaxGuidePanel));
    final tr = Tr.of(context);

    expect(find.text(tr.editorSyntaxGuideStructureSectionTitle), findsOneWidget);
    expect(find.text(tr.editorSyntaxGuideOrganisationSectionTitle), findsOneWidget);
    expect(find.text(tr.editorSyntaxGuideFormattingSectionTitle), findsOneWidget);
    // "Title page" is both this section's header and its single entry's title, so the string
    // renders twice.
    expect(find.text(tr.editorSyntaxGuideTitlePageSectionTitle), findsNWidgets(2));
  });

  testWidgets("renders every entry's title and description", (tester) async {
    _growTestSurface(tester);
    await tester.pumpWidget(_wrapWithLocalization(const OcptEditorSyntaxGuidePanel()));

    final context = tester.element(find.byType(OcptEditorSyntaxGuidePanel));
    final tr = Tr.of(context);

    final titles = [
      tr.editorBlockTypeSceneHeading,
      tr.editorBlockTypeAction,
      tr.editorBlockTypeCharacter,
      tr.editorBlockTypeParenthetical,
      tr.editorBlockTypeDialogue,
      tr.editorSyntaxGuideDualDialogueTitle,
      tr.editorBlockTypeTransition,
      tr.editorBlockTypeCenteredText,
      tr.editorBlockTypeLyrics,
      tr.editorBlockTypePageBreak,
      tr.editorBlockTypeSection,
      tr.editorBlockTypeSynopsis,
      tr.editorSyntaxGuideNoteTitle,
      tr.editorSyntaxGuideBoneyardTitle,
      tr.editorSyntaxGuideEmphasisTitle,
      tr.editorSyntaxGuideTitlePageTitle,
    ];
    expect(titles, hasLength(ocptFountainSyntaxEntries.length));
    for (final title in titles) {
      expect(find.text(title).evaluate(), isNotEmpty, reason: "missing title '$title'");
    }

    final descriptions = [
      tr.editorSyntaxGuideSceneHeadingDescription,
      tr.editorSyntaxGuideActionDescription,
      tr.editorSyntaxGuideCharacterDescription,
      tr.editorSyntaxGuideParentheticalDescription,
      tr.editorSyntaxGuideDialogueDescription,
      tr.editorSyntaxGuideDualDialogueDescription,
      tr.editorSyntaxGuideTransitionDescription,
      tr.editorSyntaxGuideCenteredTextDescription,
      tr.editorSyntaxGuideLyricsDescription,
      tr.editorSyntaxGuidePageBreakDescription,
      tr.editorSyntaxGuideSectionDescription,
      tr.editorSyntaxGuideSynopsisDescription,
      tr.editorSyntaxGuideNoteDescription,
      tr.editorSyntaxGuideBoneyardDescription,
      tr.editorSyntaxGuideEmphasisDescription,
      tr.editorSyntaxGuideTitlePageDescription,
    ];
    expect(descriptions, hasLength(ocptFountainSyntaxEntries.length));
    for (final description in descriptions) {
      expect(
        find.text(description).evaluate(),
        isNotEmpty,
        reason: "missing description '$description'",
      );
    }
  });

  testWidgets("renders one selectable snippet block per entry, in Courier Prime", (tester) async {
    _growTestSurface(tester);
    await tester.pumpWidget(_wrapWithLocalization(const OcptEditorSyntaxGuidePanel()));

    final snippetFinder = find.byType(SelectableText);
    expect(snippetFinder, findsNWidgets(ocptFountainSyntaxEntries.length));

    for (final element in snippetFinder.evaluate()) {
      final widget = element.widget as SelectableText;
      expect(widget.style?.fontFamily, OcptEditorPreviewLayout.fontFamily);
    }

    // The snippets are the literal, untranslated source lines from the table.
    for (final entry in ocptFountainSyntaxEntries) {
      expect(find.text(entry.snippetLines.join("\n")), findsOneWidget);
    }
  });

  testWidgets("scrolls without overflowing at a small constrained height", (tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const OcptEditorSyntaxGuidePanel(), height: 120));

    expect(tester.takeException(), isNull);

    // The list is actually scrollable at this height (its content is far taller than 120px).
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets("renders as static content, with no constructor parameters", (tester) async {
    // The panel has no external state or mode dependency: pumping it standalone is enough to
    // prove it behaves the same regardless of the surrounding editor mode.
    await tester.pumpWidget(_wrapWithLocalization(const OcptEditorSyntaxGuidePanel()));
    await tester.pumpAndSettle();

    expect(find.byType(OcptEditorSyntaxGuidePanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
