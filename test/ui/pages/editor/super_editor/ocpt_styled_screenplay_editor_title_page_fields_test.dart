// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  group("title page", () {
    // Every title-page widget test used to pump with `areSceneNumbersVisible: false`, while the
    // app always runs with it on — the blind spot that let F5's regression ship unnoticed. Running
    // the whole group both ways closes it: the `true` variants below must pass exactly like the
    // `false` ones once a title-page node is only ever claimed by its own component builder.
    for (final sceneNumbersVisible in [false, true]) {
      testWidgets("an empty title-page field shows its label as a placeholder hint (scene numbers: "
          "$sceneNumbersVisible)", (tester) async {
        await pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        expect(find.text("Title"), findsOneWidget);
        expect(find.text("Credit"), findsOneWidget);
        expect(find.text("Source"), findsOneWidget);
      });

      testWidgets(
        "an empty title-page field's placeholder sits exactly where the real value would be "
        "typeset "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          // The title fields sit hundreds of pixels down the simulated page: tall enough that the
          // default 800x600 test surface would leave the lower fields outside the viewport.
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          // Same "page's content area" reconstruction the page-simulation group above uses: the
          // editor's own box spans the content area widened by the stylesheet's horizontal
          // `documentPadding` inset on each side (see `OcptStyledScreenplayEditor.build`).
          final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
          const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
          final editorRect = tester.getRect(find.byType(SuperEditor));
          final pageLeftEdge = editorRect.left + inset;
          final pageRightEdge = pageLeftEdge + layout.pageWidth;
          final contentLeft = pageLeftEdge + layout.marginLeft;
          final contentRight = pageRightEdge - layout.marginRight;
          final contentCentreX = (contentLeft + contentRight) / 2;

          // Title/Credit/Author are centred on the content area, exactly like the value that will
          // replace them (this is the assertion that fails against the pre-fix
          // `TextWithHintComponent`, whose hint `Text.rich` never receives a `textAlign` and so
          // always sits flush left).
          for (final label in ["Title", "Credit", "Author"]) {
            final rect = tester.getRect(find.text(label));
            expect(rect.center.dx, closeTo(contentCentreX, 1), reason: "$label placeholder");
          }

          // Draft date is right-aligned, its text ending flush with the content area's right edge.
          final draftDateRect = tester.getRect(find.text("Draft date"));
          expect(draftDateRect.right, closeTo(contentRight, 1));
        },
      );

      testWidgets("the Title placeholder is typeset at the Title rule's own font size and weight "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Fails against the pre-fix `hintStyleBuilder`, which built a fresh `TextStyle` at body
        // size instead of decorating the Title rule's own resolved style (`fontSize * 1.6`, bold).
        final titleHint = tester.widget<Text>(find.text("Title"));
        expect(titleHint.style?.fontSize, OcptEditorPreviewLayout.fontSize * 1.6);
        expect(titleHint.style?.fontWeight, FontWeight.bold);
      });

      testWidgets(
        "the title sheet disappears entirely while page simulation is off (scene numbers: "
        "$sceneNumbersVisible)",
        (tester) async {
          await pumpStandaloneEditor(
            tester,
            "Some action.",
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          expect(find.text("Title"), findsNothing);
          final document = SuperEditorInspector.findDocument()!;
          expect(document.nodeCount, 1);
        },
      );

      testWidgets(
        "typing into the empty Title placeholder writes it into the encoded source (scene numbers: "
        "$sceneNumbersVisible)",
        (tester) async {
          // The title fields sit hundreds of pixels down the simulated page (Title alone opens with
          // a top gap landing it in the upper-middle area): tall enough that the default 800x600
          // test surface would leave it (and every field below it) outside the viewport a tap can
          // reach.
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            testWrap(
              OcptStyledScreenplayEditor(
                text: "INT. HOUSE - DAY\n\nSome action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                isSpellCheckVisible: false,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final document = SuperEditorInspector.findDocument()!;
          final titleNodeId = document.getNodeAt(0)!.id;

          await tester.placeCaretInParagraph(titleNodeId, 0);
          await tester.typeImeText("My Movie");
          await tester.pump(const Duration(milliseconds: 200));

          // The scene heading is auto-numbered by default (see the "scene numbers" group below).
          expect(encodedText, "Title: My Movie\n\nINT. HOUSE - DAY #1#\n\nSome action.");
          // The placeholder is gone now that the field has real text.
          expect(find.text("Title"), findsNothing);
        },
      );

      testWidgets(
        "pressing Enter inside the Author field adds a sibling line, not a body block (scene "
        "numbers: $sceneNumbersVisible)",
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            testWrap(
              OcptStyledScreenplayEditor(
                text: "Some action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                isSpellCheckVisible: false,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Title, Credit, Author: indices 0, 1, 2.
          final authorNodeId = SuperEditorInspector.findDocument()!.getNodeAt(2)!.id;
          await tester.placeCaretInParagraph(authorNodeId, 0);
          await tester.typeImeText("Jane Doe");
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          await tester.typeImeText("John Smith");
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          expect(document.nodeCount, 8);
          expect(
            (document.getNodeAt(2)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey),
            "Author",
          );
          expect(
            (document.getNodeAt(3)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey),
            "Author",
          );
          expect((document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "Jane Doe");
          expect((document.getNodeAt(3)! as ParagraphNode).text.toPlainText(), "John Smith");
          expect(encodedText, "Author:\n    Jane Doe\n    John Smith\n\nSome action.");
        },
      );

      testWidgets("Backspace at the start of an empty field never deletes it (scene numbers: "
          "$sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, testTitlePageFieldCount + 1);
        // Credit: index 1.
        final creditNodeId = document.getNodeAt(1)!.id;

        await placeCaretAtStartOf(tester, creditNodeId);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump(const Duration(milliseconds: 200));

        expect(document.nodeCount, testTitlePageFieldCount + 1);
        expect(document.getNodeById(creditNodeId), isNotNull);
      });

      testWidgets("Backspace at the start of a filled field never deletes it (scene numbers: "
          "$sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        final document = SuperEditorInspector.findDocument()!;
        // Credit: index 1.
        final creditNodeId = document.getNodeAt(1)!.id;
        await placeCaretAtStartOf(tester, creditNodeId);
        await tester.typeImeText("written by");
        await tester.pump(const Duration(milliseconds: 200));

        await placeCaretAtStartOf(tester, creditNodeId);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump(const Duration(milliseconds: 200));

        expect(document.nodeCount, testTitlePageFieldCount + 1);
        expect(
          (document.getNodeById(creditNodeId)! as ParagraphNode).text.toPlainText(),
          "written by",
        );
      });

      testWidgets(
        "Backspace at the start of the first body line never merges it into Source (scene numbers: "
        "$sceneNumbersVisible)",
        (tester) async {
          // Taller than the other title-page tests' own 1400x1200: with a title page present, the
          // still-open pagination defect (fixed separately, not by this change) currently renders
          // the body's first node around y=2600 instead of its eventual correct position, so the
          // surface needs enough headroom to reach it regardless of whether that fix has landed.
          tester.view.physicalSize = const Size(1400, 2700);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          final document = SuperEditorInspector.findDocument()!;
          // Source: index 5. The body's only line: index 6.
          final sourceNodeId = document.getNodeAt(5)!.id;
          final bodyNodeId = document.getNodeAt(6)!.id;

          await placeCaretAtStartOf(tester, bodyNodeId);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump(const Duration(milliseconds: 200));

          expect(document.nodeCount, testTitlePageFieldCount + 1);
          expect(document.getNodeById(sourceNodeId), isNotNull);
          expect(
            (document.getNodeById(bodyNodeId)! as ParagraphNode).text.toPlainText(),
            "Some action.",
          );
        },
      );

      testWidgets(
        "Backspace can still remove an extra line added to a multi-line field (scene numbers: "
        "$sceneNumbersVisible)",
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          // Title, Credit, Author: indices 0, 1, 2.
          final authorNodeId = SuperEditorInspector.findDocument()!.getNodeAt(2)!.id;
          await placeCaretAtStartOf(tester, authorNodeId);
          await tester.typeImeText("Jane Doe");
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          await tester.typeImeText("John Smith");
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          expect(document.nodeCount, testTitlePageFieldCount + 2);
          final secondAuthorLineId = document.getNodeAt(3)!.id;

          await placeCaretAtStartOf(tester, secondAuthorLineId);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump(const Duration(milliseconds: 200));

          expect(document.nodeCount, testTitlePageFieldCount + 1);
          expect(
            (document.getNodeAt(2)! as ParagraphNode).text.toPlainText(),
            "Jane DoeJohn Smith",
          );
          expect(
            (document.getNodeAt(2)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey),
            "Author",
          );
        },
      );

      testWidgets("typing into a field then pressing Backspace deletes the last character "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        // The F6 defect itself: `NodeMetadata.isDeletable: false` used to make
        // `DeleteContentCommand`/`DeleteSelectionCommand` abort *any* deletion inside a single
        // title-page node, not just the node's own removal — so typed text could never be
        // shortened, only added to.
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? encodedText;

        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "Some action.",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: true,
              areSceneNumbersVisible: sceneNumbersVisible,
              isSpellCheckVisible: false,
              onTextChanged: (text) => encodedText = text,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Credit: index 1.
        final creditNodeId = SuperEditorInspector.findDocument()!.getNodeAt(1)!.id;
        await placeCaretAtStartOf(tester, creditNodeId);
        await tester.typeImeText("written by");
        await tester.pump(const Duration(milliseconds: 200));

        // The caret sits at the end of "written by" (offset 10): a plain hardware Backspace, the
        // same key `CommonEditorOperations.deleteUpstreamCharacter`-driven path a real desktop
        // keypress travels through.
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          (SuperEditorInspector.findDocument()!.getNodeById(creditNodeId)! as ParagraphNode).text
              .toPlainText(),
          "written b",
        );
        expect(encodedText, contains("Credit: written b\n"));
      });

      testWidgets("deleting a selection inside a field removes just the selection "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? encodedText;

        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "Some action.",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: true,
              areSceneNumbersVisible: sceneNumbersVisible,
              isSpellCheckVisible: false,
              onTextChanged: (text) => encodedText = text,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Credit: index 1.
        final creditNodeId = SuperEditorInspector.findDocument()!.getNodeAt(1)!.id;
        await placeCaretAtStartOf(tester, creditNodeId);
        await tester.typeImeText("written by");
        await tester.pump(const Duration(milliseconds: 200));

        // Extend the selection upstream over the last two characters ("by"), then delete them —
        // exactly the "typing over/deleting an expanded selection inside a field" case F2's flag
        // used to also silently block.
        await sendShift(tester, LogicalKeyboardKey.arrowLeft);
        await sendShift(tester, LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          (SuperEditorInspector.findDocument()!.getNodeById(creditNodeId)! as ParagraphNode).text
              .toPlainText(),
          "written ",
        );
        expect(encodedText, contains("Credit: written \n"));
      });

      testWidgets(
        "select-all then Delete clears the body but leaves the six title-page fields standing "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          // Taller than most other title-page tests' own 1400x1200: with a title page present, the
          // still-open pagination defect (fixed separately, not by this change) currently renders
          // the body's first node around y=2600 instead of its eventual correct position, but this
          // test never needs to see the body at all — only the surface needs to be wide enough for
          // the widget tree to lay out without throwing.
          tester.view.physicalSize = const Size(1400, 2700);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            testWrap(
              OcptStyledScreenplayEditor(
                text: "INT. HOUSE - DAY\n\nSome action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                isSpellCheckVisible: false,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final fieldIds = [
            for (var index = 0; index < testTitlePageFieldCount; index++)
              SuperEditorInspector.findDocument()!.getNodeAt(index)!.id,
          ];

          // Ctrl+A only reaches `SuperEditor`'s keyboard handlers once it has focus: place a caret
          // first, exactly like a real user would before selecting everything.
          await placeCaretAtStartOf(tester, fieldIds.first);

          await sendCtrl(tester, LogicalKeyboardKey.keyA);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          // The two deleted body nodes (heading + action) are replaced by a single fresh empty one:
          // the six fields are untouched, so the sheet still always has all of them.
          expect(document.nodeCount, testTitlePageFieldCount + 1);
          for (final fieldId in fieldIds) {
            expect(document.getNodeById(fieldId), isNotNull, reason: "field node $fieldId");
          }
          expect(
            (document.getNodeAt(testTitlePageFieldCount)! as ParagraphNode).text.toPlainText(),
            isEmpty,
          );
          expect(encodedText, "");
        },
      );

      testWidgets("the Draft date and Contact placeholders share the same row, split at the page's "
          "horizontal centre "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Same "page's content area" reconstruction the earlier placeholder-alignment test uses.
        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
        const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
        final editorRect = tester.getRect(find.byType(SuperEditor));
        final pageLeftEdge = editorRect.left + inset;
        final pageRightEdge = pageLeftEdge + layout.pageWidth;
        final contentLeft = pageLeftEdge + layout.marginLeft;
        final contentRight = pageRightEdge - layout.marginRight;
        final contentCentreX = (contentLeft + contentRight) / 2;

        final draftDateRect = tester.getRect(find.text("Draft date"));
        final contactRect = tester.getRect(find.text("Contact"));

        // Same row (Contact's own top gap is 0; the shift takes its place), split at the centre:
        // Contact stops at or before it, Draft date starts at or after it.
        expect(draftDateRect.top, closeTo(contactRect.top, 1));
        expect(contactRect.right, lessThanOrEqualTo(contentCentreX + 1));
        expect(draftDateRect.left, greaterThanOrEqualTo(contentCentreX - 1));
      });

      testWidgets("a filled Draft date and Contact still share the same row (scene numbers: "
          "$sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Draft date, Contact: indices 3, 4.
        final document = SuperEditorInspector.findDocument()!;
        final draftDateNodeId = document.getNodeAt(3)!.id;
        final contactNodeId = document.getNodeAt(4)!.id;

        await placeCaretAtStartOf(tester, draftDateNodeId);
        await tester.typeImeText("2026-07-26");
        await tester.pump(const Duration(milliseconds: 200));

        await placeCaretAtStartOf(tester, contactNodeId);
        await tester.typeImeText("Jane Doe");
        await tester.pump(const Duration(milliseconds: 200));

        // A filled node's own text no longer renders through a plain `Text` widget this builder
        // controls (unlike the empty placeholder), so the component's own box — read straight off
        // its `RenderBox`, the same way `SuperEditorInspector` and the document layout's own hit
        // testing both do — is what stands in for "where the field visually sits" here.
        final draftDateOffset = SuperEditorInspector.findComponentOffset(
          draftDateNodeId,
          Alignment.topRight,
        );
        final contactOffset = SuperEditorInspector.findComponentOffset(
          contactNodeId,
          Alignment.topLeft,
        );
        final contactSize = SuperEditorInspector.findComponentSize(contactNodeId);

        expect(draftDateOffset.dy, closeTo(contactOffset.dy, 1));
        expect(contactOffset.dx + contactSize.width, lessThanOrEqualTo(draftDateOffset.dx + 1));
      });

      testWidgets(
        "tapping the Draft date and Contact fields routes the caret to the right node, not the "
        "other "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          // The risky assertion: it proves the paint-time shift `OcptTitlePageComponentBuilder`
          // applies to Contact/Source does not also move where a tap is hit-tested to, since both
          // are derived from the exact same (transformed) component `RenderBox` (see that builder's
          // own doc comment). A regression here would make one field swallow the other's clicks.
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          final document = SuperEditorInspector.findDocument()!;
          final draftDateNodeId = document.getNodeAt(3)!.id;
          final contactNodeId = document.getNodeAt(4)!.id;

          await placeCaretAtStartOf(tester, draftDateNodeId);
          await placeCaretAtStartOf(tester, contactNodeId);
        },
      );

      testWidgets(
        "a multi-line Contact still stacks under the row, and Source follows with no leftover gap "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          // Contact: index 4.
          final contactNodeId = SuperEditorInspector.findDocument()!.getNodeAt(4)!.id;
          await placeCaretAtStartOf(tester, contactNodeId);
          await tester.typeImeText("123 Reel Street");
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          await tester.typeImeText("Second line");
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          expect(document.nodeCount, testTitlePageFieldCount + 2);
          // Title, Credit, Author, Draft date, Contact (first line): indices 0-4. Contact's second
          // line and Source follow at 5 and 6.
          final firstLineId = document.getNodeAt(4)!.id;
          final secondLineId = document.getNodeAt(5)!.id;
          final sourceNodeId = document.getNodeAt(6)!.id;

          final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
          final firstLineTop = SuperEditorInspector.findComponentOffset(
            firstLineId,
            Alignment.topLeft,
          ).dy;
          final secondLineOffset = SuperEditorInspector.findComponentOffset(
            secondLineId,
            Alignment.topLeft,
          );
          final secondLineHeight = SuperEditorInspector.findComponentSize(secondLineId).height;
          // The two Contact lines stack with no gap between them, exactly one lineHeight apart.
          expect(secondLineOffset.dy - firstLineTop, closeTo(layout.lineHeight, 1));

          // Source keeps its usual one-line gap below the last Contact line, unaffected by the
          // shift: both nodes are painted with the exact same `rowShift` translation, so their
          // relative spacing is exactly what it was before this node ever needed shifting.
          final sourceTop = SuperEditorInspector.findComponentOffset(
            sourceNodeId,
            Alignment.topLeft,
          ).dy;
          expect(
            sourceTop - (secondLineOffset.dy + secondLineHeight),
            closeTo(layout.lineHeight, 1),
          );
        },
      );

      testWidgets(
        "the shared Draft date/Contact row is purely visual: the encoded source is unaffected "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            testWrap(
              OcptStyledScreenplayEditor(
                text: "Some action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                isSpellCheckVisible: false,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final document = SuperEditorInspector.findDocument()!;
          final draftDateNodeId = document.getNodeAt(3)!.id;
          final contactNodeId = document.getNodeAt(4)!.id;

          await tester.placeCaretInParagraph(draftDateNodeId, 0);
          await tester.typeImeText("2026-07-26");
          await tester.pump(const Duration(milliseconds: 200));

          await tester.placeCaretInParagraph(contactNodeId, 0);
          await tester.typeImeText("jane@example.com");
          await tester.pump(const Duration(milliseconds: 200));

          expect(encodedText, "Draft date: 2026-07-26\nContact: jane@example.com\n\nSome action.");
        },
      );
    }
  });
}
