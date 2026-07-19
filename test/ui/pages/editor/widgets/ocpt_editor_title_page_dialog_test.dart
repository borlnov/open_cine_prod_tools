// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_title_page_dialog.dart';

/// A router manager whose [pop] only records the last call and its value: this dialog is pumped
/// directly, without a real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// A placeholder range for entries built directly (never read by the dialog).
const _dummyRange = FountainSourceRange(startLine: 0, endLine: 0, startOffset: 0, endOffset: 0);

void main() {
  late _RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps [OcptEditorTitlePageDialog] directly (no [showDialog]/`.show`), pre-filled with
  /// [current].
  Future<void> pumpDialog(WidgetTester tester, {FountainTitlePage? current}) async {
    await tester.pumpWidget(_wrapWithLocalization(OcptEditorTitlePageDialog(current: current)));
    await tester.pumpAndSettle();
  }

  /// The current text of the [TextFormField] labelled [label].
  String? fieldText(WidgetTester tester, String label) => tester
      .widget<TextFormField>(find.widgetWithText(TextFormField, label))
      .controller
      ?.text;

  testWidgets("prefills every field from the parsed title page's raw joined values", (tester) async {
    const titlePage = FountainTitlePage(
      entries: [
        FountainTitlePageEntry(key: 'Title', values: ['My Screenplay'], sourceRange: _dummyRange),
        FountainTitlePageEntry(key: 'Credit', values: ['written by'], sourceRange: _dummyRange),
        FountainTitlePageEntry(
          key: 'Author',
          values: ['Jane Doe and John Smith'],
          sourceRange: _dummyRange,
        ),
        FountainTitlePageEntry(key: 'Draft date', values: ['7/12/2026'], sourceRange: _dummyRange),
        FountainTitlePageEntry(
          key: 'Contact',
          values: ['Line one', 'Line two'],
          sourceRange: _dummyRange,
        ),
        FountainTitlePageEntry(key: 'Source', values: ['Original idea'], sourceRange: _dummyRange),
      ],
      sourceRange: _dummyRange,
    );

    await pumpDialog(tester, current: titlePage);
    final context = tester.element(find.byType(OcptEditorTitlePageDialog));
    final tr = Tr.of(context);

    expect(fieldText(tester, tr.editorTitlePageTitleLabel), 'My Screenplay');
    expect(fieldText(tester, tr.editorTitlePageCreditLabel), 'written by');
    // The raw joined value, not the semantically re-split/re-joined `authors` getter's form.
    expect(fieldText(tester, tr.editorTitlePageAuthorLabel), 'Jane Doe and John Smith');
    expect(fieldText(tester, tr.editorTitlePageDraftDateLabel), '7/12/2026');
    expect(fieldText(tester, tr.editorTitlePageContactLabel), 'Line one Line two');
    expect(fieldText(tester, tr.editorTitlePageSourceLabel), 'Original idea');
  });

  testWidgets("prefills every field blank when there is no title page", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptEditorTitlePageDialog));
    final tr = Tr.of(context);

    expect(fieldText(tester, tr.editorTitlePageTitleLabel), '');
    expect(fieldText(tester, tr.editorTitlePageCreditLabel), '');
    expect(fieldText(tester, tr.editorTitlePageAuthorLabel), '');
    expect(fieldText(tester, tr.editorTitlePageDraftDateLabel), '');
    expect(fieldText(tester, tr.editorTitlePageContactLabel), '');
    expect(fieldText(tester, tr.editorTitlePageSourceLabel), '');
  });

  testWidgets("editing a field then tapping Apply pops the router manager with the record", (
    tester,
  ) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptEditorTitlePageDialog));
    final tr = Tr.of(context);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.editorTitlePageTitleLabel),
      "  My New Screenplay  ",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.editorTitlePageAuthorLabel),
      "Jane Doe",
    );
    await tester.tap(find.text(tr.editorPageSetupApplyAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final popped =
        routerManager.poppedValue!
            as ({
              String title,
              String credit,
              String author,
              String draftDate,
              String contact,
              String source,
            });
    expect(popped.title, "My New Screenplay");
    expect(popped.author, "Jane Doe");
    expect(popped.credit, "");
    expect(popped.draftDate, "");
    expect(popped.contact, "");
    expect(popped.source, "");
  });

  testWidgets("Cancel pops with no value", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptEditorTitlePageDialog));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.editorPageSetupCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}
