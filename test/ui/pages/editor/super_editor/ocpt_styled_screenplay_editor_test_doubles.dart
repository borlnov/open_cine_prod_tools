// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

/// Wraps [child] with a [MaterialApp] and a bounded, sized surface: `SuperEditor` needs a
/// constrained size to lay its document out. The localization delegates are needed for the
/// title-page placeholder builder's field labels, which only ever resolve while page simulation
/// is on (see the "page simulation" group below).
Widget testWrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox.expand(child: child)),
);

/// A bare [OcptStyledScreenplayEditor] pumped with [text] and no bloc behind it: most of the
/// tests below only care about the live super_editor document a keyboard interaction produces,
/// not about autosave/dirty tracking (already covered by the bloc-wired group above).
///
/// Pass a distinct [key] whenever a single `testWidgets` body calls this more than once with the
/// same [text] (for example, pumping a fresh instance per case in a loop): otherwise
/// `_OcptStyledScreenplayEditorState.didUpdateWidget`'s own "only rebuild the document if the text
/// actually changed" guard sees an unchanged [text] across the identically-shaped widget tree and
/// keeps reusing the previous call's already-edited live document instead of starting fresh.
Future<void> pumpStandaloneEditor(
  WidgetTester tester,
  String text, {
  Key? key,
  OcptStyledEditorController? styledController,
  bool isPageSimulationEnabled = false,
  bool areSceneNumbersVisible = false,
  bool isSpellCheckVisible = false,
  Future<List<String>> Function(String word)? onSpellingSuggestionsRequested,
  ValueChanged<String>? onWordIgnored,
  ValueChanged<String>? onWordLearned,
}) async {
  await tester.pumpWidget(
    testWrap(
      OcptStyledScreenplayEditor(
        key: key,
        text: text,
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: isPageSimulationEnabled,
        areSceneNumbersVisible: areSceneNumbersVisible,
        isSpellCheckVisible: isSpellCheckVisible,
        onTextChanged: (_) {},
        onCaretLineChanged: (_) {},
        jumpRequest: null,
        styledController: styledController,
        onSpellingSuggestionsRequested: onSpellingSuggestionsRequested,
        onWordIgnored: onWordIgnored,
        onWordLearned: onWordLearned,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The number of leading title-page field nodes a page-simulation-on document starts with when
/// its source text has no title page of its own: all six [ocptTitlePageFieldKeys] then synthesize
/// as one empty node each (see `OcptWysiwygCodec.decodeWithTitlePage`), ahead of every body node
/// the "page simulation" test group below otherwise indexes by position.
const int testTitlePageFieldCount = 6;

/// Places the caret at the start of the node with [nodeId] and asserts it actually landed there,
/// so a silently-failed tap (for example a field sitting outside the test surface's viewport, see
/// the title-page tests' own `tester.view.physicalSize` overrides) can never be mistaken for the
/// Backspace guard doing its job — every caller below would otherwise still pass even if the
/// caret, and with it the whole gesture, never actually reached the target field.
Future<void> placeCaretAtStartOf(WidgetTester tester, String nodeId) async {
  await tester.placeCaretInParagraph(nodeId, 0);
  final selection = SuperEditorInspector.findDocumentSelection();
  expect(selection, isNotNull, reason: "caret placement in node $nodeId failed");
  expect(selection!.extent.nodeId, nodeId);
  expect((selection.extent.nodePosition as TextNodePosition).offset, 0);
}

/// The node at [index] of [document], freshly re-read: every node-metadata/block-type change
/// (`ChangeParagraphBlockTypeRequest`, `OcptChangeNodeMetadataRequest`) replaces the node object
/// in place rather than mutating it, so a [ParagraphNode] reference captured before such a change
/// goes stale; call this again after every edit instead of reusing an old reference.
ParagraphNode nodeAt(Document document, int index) => document.getNodeAt(index)! as ParagraphNode;

/// The [FountainLineType] the node at [index] of [document] is currently classified as.
FountainLineType typeAt(Document document, int index) =>
    OcptFountainLineAttributions.typeOfAttributionValue(
      nodeAt(document, index).getMetadataValue("blockType"),
    );

/// Whether the node at [index] of [document] currently carries a manual type lock.
bool isLockedAt(Document document, int index) =>
    nodeAt(document, index).getMetadataValue(ocptTypeLockedMetadataKey) == true;

/// The node at [index] of [document]'s `ocptSceneNumber` metadata, or null if absent.
String? sceneNumberAt(Document document, int index) {
  final value = nodeAt(document, index).getMetadataValue(ocptSceneNumberMetadataKey);
  return value is String ? value : null;
}

/// Pumps past the styled editor's 120 ms settle debounce (`_syncAfterEdit`) and lets the rebuild
/// it causes finish, so an assertion that follows sees the document the editor actually settles
/// on rather than the raw result of the keystroke.
///
/// `pumpAndSettle` alone is not enough: a pending `Timer` schedules no frame of its own, so
/// `pumpAndSettle` can decide the tree is idle and stop before the debounce ever fires.
Future<void> pumpPastSettleDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
}

/// Sends the hardware key combo for [key] with Ctrl held (Cmd has no equivalent test helper here;
/// this app targets Linux/Windows first).
Future<void> sendCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

/// Sends the hardware key combo for [key] with Shift held.
Future<void> sendShift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

/// Sends the hardware key combo for [key] with both Ctrl and Shift held (Ctrl+Shift+Z's redo, which
/// neither [sendCtrl] nor [sendShift] alone can produce).
Future<void> sendCtrlShift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}
