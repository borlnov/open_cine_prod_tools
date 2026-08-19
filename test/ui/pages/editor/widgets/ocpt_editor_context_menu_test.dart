// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_context_menu.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, matching
/// `ocpt_editor_block_type_dropdown_test.dart`'s own helper.
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

void main() {
  testWidgets("shows up to five suggestions over a misspelled word, capped", (tester) async {
    final controller = MenuController();

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorContextMenu(
          controller: controller,
          childFocusNode: FocusNode(),
          misspelledWord: "wrold",
          suggestions: const ["world", "word", "wold", "wormed", "wrote", "wrong"],
          onSuggestionSelected: (_) {},
          onIgnoreWord: () {},
          onLearnWord: () {},
          currentType: null,
          onCut: null,
          onCopy: null,
          onPaste: null,
          onSelectAll: null,
          onTypeSelected: null,
          child: const SizedBox(),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();

    for (final suggestion in ["world", "word", "wold", "wormed", "wrote"]) {
      expect(find.text(suggestion), findsOneWidget, reason: "missing suggestion $suggestion");
    }
    expect(find.text("wrong"), findsNothing);
  });

  testWidgets("tapping a suggestion invokes onSuggestionSelected with that suggestion", (tester) async {
    String? selected;
    final controller = MenuController();

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorContextMenu(
          controller: controller,
          childFocusNode: FocusNode(),
          misspelledWord: "wrold",
          suggestions: const ["world"],
          onSuggestionSelected: (suggestion) => selected = suggestion,
          onIgnoreWord: () {},
          onLearnWord: () {},
          currentType: null,
          onCut: null,
          onCopy: null,
          onPaste: null,
          onSelectAll: null,
          onTypeSelected: null,
          child: const SizedBox(),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();
    await tester.tap(find.text("world"));
    await tester.pumpAndSettle();

    expect(selected, "world");
  });

  testWidgets("tapping Ignore this word invokes onIgnoreWord", (tester) async {
    var ignored = false;
    final controller = MenuController();

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorContextMenu(
          controller: controller,
          childFocusNode: FocusNode(),
          misspelledWord: "wrold",
          onSuggestionSelected: (_) {},
          onIgnoreWord: () => ignored = true,
          onLearnWord: () {},
          currentType: null,
          onCut: null,
          onCopy: null,
          onPaste: null,
          onSelectAll: null,
          onTypeSelected: null,
          child: const SizedBox(),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();
    await tester.tap(find.text("Ignore this word"));
    await tester.pumpAndSettle();

    expect(ignored, isTrue);
  });

  testWidgets("tapping Add to the project's dictionary invokes onLearnWord", (tester) async {
    var learned = false;
    final controller = MenuController();

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorContextMenu(
          controller: controller,
          childFocusNode: FocusNode(),
          misspelledWord: "wrold",
          onSuggestionSelected: (_) {},
          onIgnoreWord: () {},
          onLearnWord: () => learned = true,
          currentType: null,
          onCut: null,
          onCopy: null,
          onPaste: null,
          onSelectAll: null,
          onTypeSelected: null,
          child: const SizedBox(),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();
    await tester.tap(find.text("Add to the project's dictionary"));
    await tester.pumpAndSettle();

    expect(learned, isTrue);
  });

  testWidgets("withholds the whole spelling group when there is no misspelled word", (tester) async {
    final controller = MenuController();

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorContextMenu(
          controller: controller,
          childFocusNode: FocusNode(),
          // misspelledWord left at its default (null): the case under test.
          suggestions: const ["world"],
          onSuggestionSelected: (_) {},
          onIgnoreWord: () {},
          onLearnWord: () {},
          currentType: null,
          onCut: () {},
          onCopy: null,
          onPaste: null,
          onSelectAll: null,
          onTypeSelected: null,
          child: const SizedBox(),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();

    expect(find.text("world"), findsNothing);
    expect(find.text("Ignore this word"), findsNothing);
    expect(find.text("Add to the project's dictionary"), findsNothing);
    // The clipboard entry withheld for a null callback is absent, exactly as it was before this
    // milestone — the spelling group's absence must not somehow drag anything else down with it.
    expect(find.text("Cut"), findsOneWidget);
  });

  testWidgets(
    "draws a divider after the suggestions, another before the clipboard entries, and a third "
    "before the block-type submenu",
    (tester) async {
      final controller = MenuController();

      await tester.pumpWidget(
        _wrapWithLocalization(
          OcptEditorContextMenu(
            controller: controller,
            childFocusNode: FocusNode(),
            misspelledWord: "wrold",
            suggestions: const ["world"],
            onSuggestionSelected: (_) {},
            onIgnoreWord: () {},
            onLearnWord: () {},
            currentType: null,
            onCut: () {},
            onCopy: null,
            onPaste: null,
            onSelectAll: null,
            onTypeSelected: null,
            child: const SizedBox(),
          ),
        ),
      );

      controller.open();
      await tester.pumpAndSettle();

      // One divider between the suggestion and the two spelling actions, one more between the
      // spelling group and Cut: the block-type submenu isn't offered here, so there is nothing for
      // a third divider to separate.
      expect(find.byType(Divider), findsNWidgets(2));
    },
  );

  testWidgets("draws no divider between the suggestions and the actions when there are no suggestions", (
    tester,
  ) async {
    final controller = MenuController();

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorContextMenu(
          controller: controller,
          childFocusNode: FocusNode(),
          misspelledWord: "wrold",
          onSuggestionSelected: (_) {},
          onIgnoreWord: () {},
          onLearnWord: () {},
          currentType: null,
          onCut: () {},
          onCopy: null,
          onPaste: null,
          onSelectAll: null,
          onTypeSelected: null,
          child: const SizedBox(),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();

    // Only the divider separating the spelling group (Ignore/Add, with no suggestions above them)
    // from Cut below it.
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets("draws no divider at all when there is nothing on either side of the spelling group", (
    tester,
  ) async {
    final controller = MenuController();

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorContextMenu(
          controller: controller,
          childFocusNode: FocusNode(),
          misspelledWord: "wrold",
          onSuggestionSelected: (_) {},
          onIgnoreWord: () {},
          onLearnWord: () {},
          currentType: null,
          onCut: null,
          onCopy: null,
          onPaste: null,
          onSelectAll: null,
          onTypeSelected: null,
          child: const SizedBox(),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNothing);
  });
}
