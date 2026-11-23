// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_controls.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_overflow_menu.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Two speeches that can be paired, then an action line.
const String _twoSpeeches = "ROSS\nHello.\n\nKIM\nHi there.\n\nEND.\n";

/// Pump a styled editor over [text] with [controller] and the format controls above it.
Future<void> _pump(
  WidgetTester tester,
  String text,
  OcptStyledEditorController controller, {
  bool isOverflow = false,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testWrap(
      Column(
        children: [
          if (isOverflow)
            OcptEditorFormatOverflowMenu(controller: controller)
          else
            OcptEditorFormatControls(controller: controller),
          Expanded(
            child: OcptStyledScreenplayEditor(
              text: text,
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (_) {},
              onCaretLineChanged: (_) {},
              jumpRequest: null,
              styledController: controller,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The dual-dialogue suffix of the node at [index] of [document].
String? _suffixAt(Document document, int index) =>
    OcptWysiwygDualDialogue.suffixOf(nodeAt(document, index));

/// Run the tests of the dual-dialogue toggle.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("the toolbar toggle", () {
    testWidgets("pairs the second speech with the first, in one undo step", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      await _pump(tester, _twoSpeeches, controller);
      final tr = Tr.of(tester.element(find.byType(OcptEditorFormatControls)));
      final document = SuperEditorInspector.findDocument()!;
      expect(find.byTooltip(tr.editorDualDialogueTooltip), findsNothing);

      await tester.placeCaretInParagraph(nodeAt(document, 3).id, 1);
      await tester.pump();
      expect(controller.canToggleDualDialogue, isTrue);
      expect(controller.isDualDialogueChecked, isFalse);

      await tester.tap(find.byTooltip(tr.editorDualDialogueTooltip));
      await pumpPastSettleDebounce(tester);

      expect(_suffixAt(document, 2), " ^");
      expect(controller.isDualDialogueChecked, isTrue);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);

      expect(_suffixAt(document, 2), isNull);
      expect(controller.isDualDialogueChecked, isFalse);
    });

    testWidgets("unpairs from the first speech of a pair", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      await _pump(tester, "ROSS\nHello.\n\nKIM ^\nHi there.\n", controller);
      final tr = Tr.of(tester.element(find.byType(OcptEditorFormatControls)));
      final document = SuperEditorInspector.findDocument()!;

      await tester.placeCaretInParagraph(nodeAt(document, 1).id, 1);
      await tester.pump();
      expect(controller.isDualDialogueChecked, isTrue);

      await tester.tap(find.byTooltip(tr.editorDualDialogueTooltip));
      await pumpPastSettleDebounce(tester);

      expect(_suffixAt(document, 2), isNull);
    });

    testWidgets("is withheld with no other speech next to the caret's", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      await _pump(tester, "ROSS\nHello.\n\nEND.\n", controller);
      final tr = Tr.of(tester.element(find.byType(OcptEditorFormatControls)));
      final document = SuperEditorInspector.findDocument()!;

      await tester.placeCaretInParagraph(nodeAt(document, 1).id, 1);
      await tester.pump();
      expect(controller.canToggleDualDialogue, isFalse);
      expect(find.byTooltip(tr.editorDualDialogueTooltip), findsNothing);

      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 1);
      await tester.pump();
      expect(controller.canToggleDualDialogue, isFalse);
    });

    testWidgets("is in the overflow menu too", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      await _pump(tester, _twoSpeeches, controller, isOverflow: true);
      final tr = Tr.of(tester.element(find.byType(OcptEditorFormatOverflowMenu)));
      final document = SuperEditorInspector.findDocument()!;

      await tester.placeCaretInParagraph(nodeAt(document, 3).id, 1);
      await tester.pump();
      await tester.tap(find.byTooltip(tr.editorFormatMenuTooltip));
      await tester.pumpAndSettle();
      expect(find.text(tr.editorDualDialogueAction), findsOneWidget);

      await tester.tap(find.text(tr.editorDualDialogueAction));
      await pumpPastSettleDebounce(tester);
      expect(_suffixAt(document, 2), " ^");
    });

    testWidgets("is withheld from the overflow menu where it has nothing to act on", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      await _pump(tester, "END.\n", controller, isOverflow: true);
      final tr = Tr.of(tester.element(find.byType(OcptEditorFormatOverflowMenu)));
      final document = SuperEditorInspector.findDocument()!;

      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 1);
      await tester.pump();
      await tester.tap(find.byTooltip(tr.editorFormatMenuTooltip));
      await tester.pumpAndSettle();

      expect(find.text(tr.editorDualDialogueAction), findsNothing);
    });
  });

  group("the shortcut", () {
    testWidgets("Ctrl+Alt+D toggles the pair", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      await _pump(tester, _twoSpeeches, controller);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 3).id, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await pumpPastSettleDebounce(tester);

      expect(_suffixAt(document, 2), " ^");
      expect(nodeAt(document, 3).text.toPlainText(), "Hi there.");
    });
  });

  group("the right-click menu", () {
    /// Right-click inside the node [nodeId] and return the translations.
    Future<Tr> rightClick(WidgetTester tester, String nodeId) async {
      final offset =
          SuperEditorInspector.findComponentOffset(nodeId, Alignment.centerLeft) +
          const Offset(4, 0);
      await tester.tapAt(offset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      return Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
    }

    testWidgets("offers the entry in a speech with another next to it, checkable", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        await _pump(tester, _twoSpeeches, controller);
        final document = SuperEditorInspector.findDocument()!;

        final tr = await rightClick(tester, nodeAt(document, 3).id);
        expect(find.text(tr.editorDualDialogueAction), findsOneWidget);
        expect(tester.widget<CheckboxMenuButton>(find.byType(CheckboxMenuButton)).value, isFalse);

        await tester.tap(find.text(tr.editorDualDialogueAction));
        await pumpPastSettleDebounce(tester);
        expect(_suffixAt(document, 2), " ^");

        await rightClick(tester, nodeAt(document, 3).id);
        expect(tester.widget<CheckboxMenuButton>(find.byType(CheckboxMenuButton)).value, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets("withholds the entry from a line that is no speech", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        await _pump(tester, _twoSpeeches, controller);
        final document = SuperEditorInspector.findDocument()!;

        final tr = await rightClick(tester, nodeAt(document, 4).id);

        expect(find.text(tr.editorDualDialogueAction), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
