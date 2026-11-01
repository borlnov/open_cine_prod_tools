// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'editor_page_scenarios_test_doubles.dart';

void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final harness = EditorScenarioHarness();

  setUpAll(harness.setUpAll);
  tearDownAll(harness.tearDownAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Moves the window to [width] and lets the shell rearrange itself.
  Future<void> resizeTo(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// The styled editor's document.
  MutableDocument styledDocument() => SuperEditorInspector.findDocument()! as MutableDocument;

  /// Makes a real styled edit on the last block and leaves it pending.
  Future<void> editLastBlock(WidgetTester tester) async {
    final last = styledDocument().getNodeAt(styledDocument().nodeCount - 1)! as ParagraphNode;
    await tester.placeCaretInParagraph(last.id, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets("a pending styled edit survives the window crossing the compact breakpoint", (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
      await harness.mountWorkspace(tester);
      await editLastBlock(tester);

      await resizeTo(tester, 700);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);
      expect(find.byType(SuperEditor), findsOneWidget);
      expect(styledDocument().getNodeAt(styledDocument().nodeCount - 1), isA<ParagraphNode>());

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(await harness.storedText(), contains("@SOMETHING MOVES IN THE DARK."));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets("leaving the page right after a styled edit flushes it to the project", (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
      await harness.mount(tester);
      await editLastBlock(tester);

      await harness.unmount(tester);

      expect(tester.takeException(), isNull);
      expect(await harness.storedText(), contains("@SOMETHING MOVES IN THE DARK."));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
