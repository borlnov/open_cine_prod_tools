// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

/// Wraps [child] with a [MaterialApp] and a bounded, sized surface: `SuperEditor` needs a
/// constrained size to lay its document out. Mirrors `ocpt_styled_screenplay_editor_test.dart`'s
/// own `_wrap` helper (kept as its own private copy here, rather than shared, per this project's
/// "inline private test doubles, no shared helpers directory" convention) — including the
/// localization delegates, needed since the styled editor's right-click context menu resolves
/// `Tr.of(context)` unconditionally while building, in every mode, not just page simulation.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox.expand(child: child)),
);

/// Full-corpus smoke test through the *live* `OcptStyledScreenplayEditor` widget: unlike
/// `ocpt_wysiwyg_codec_test.dart`'s corpus group (which only calls the pure
/// `OcptWysiwygCodec.decode`/`encode` functions and never builds a widget tree), this test pumps
/// the real widget with every corpus file's text and asserts it builds a non-empty live document
/// without throwing — catching stylesheet crashes or layout exceptions a pure codec test cannot
/// see. It deliberately does not re-assert exact round-trip byte-identity, already covered there.
void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; set here for consistency with every other file that pumps this widget,
  // even though none of the cases below place a selection of their own.
  BlinkController.indeterminateAnimationsEnabled = false;

  group("OcptStyledScreenplayEditor builds every fountain_kit corpus file without crashing", () {
    final corpusDirectory = Directory("packages/fountain_kit/test/corpus");
    final corpusFiles =
        corpusDirectory.listSync().whereType<File>().where((file) => file.path.endsWith(".fountain")).toList(
          growable: false,
        )..sort((a, b) => a.path.compareTo(b.path));

    test("the corpus directory is not empty", () {
      expect(corpusFiles, isNotEmpty);
    });

    for (final file in corpusFiles) {
      final fileName = file.uri.pathSegments.last;

      testWidgets("$fileName builds a non-empty live document", (tester) async {
        final text = file.readAsStringSync();

        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: text,
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: true,
              onTextChanged: (_) {},
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument();
        expect(document, isNotNull, reason: "$fileName failed to build a live document");
        expect(document!.nodeCount, greaterThan(0), reason: "$fileName built an empty document");
      });
    }
  });
}
