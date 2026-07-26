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
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_page_setup_dialog.dart';

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

  /// Pumps [OcptEditorPageSetupDialog] directly (no [showDialog]/`.show`), pre-filled with
  /// [current] (defaulting to the standard setup).
  Future<void> pumpDialog(
    WidgetTester tester, {
    OcptPageSetup current = const OcptPageSetup.standard(),
  }) async {
    await tester.pumpWidget(_wrapWithLocalization(OcptEditorPageSetupDialog(current: current)));
    await tester.pumpAndSettle();
  }

  testWidgets("editing a margin then tapping Apply pops the router manager with it", (
    tester,
  ) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptEditorPageSetupDialog));
    final tr = Tr.of(context);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.editorPageSetupMarginLeftLabel),
      "2",
    );
    await tester.tap(find.text(tr.editorPageSetupApplyAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final popped = routerManager.poppedValue! as OcptPageSetup;
    expect(popped.format, OcptPageFormat.usLetter);
    expect(popped.margins.leftInches, 2);
    expect(popped.margins.rightInches, const FountainPageMargins.standard().rightInches);
  });

  testWidgets("entering a non-numeric margin blocks Apply and shows the validator error", (
    tester,
  ) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptEditorPageSetupDialog));
    final tr = Tr.of(context);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.editorPageSetupMarginLeftLabel),
      "not a number",
    );
    await tester.tap(find.text(tr.editorPageSetupApplyAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isFalse);
    expect(find.text(tr.editorPageSetupMarginNotANumberError), findsOneWidget);
  });

  testWidgets('"Reset to standard margins" refills every field to 1.5/1/1/1', (tester) async {
    await pumpDialog(
      tester,
      current: const OcptPageSetup(
        format: OcptPageFormat.usLetter,
        margins: FountainPageMargins(
          leftInches: 2,
          rightInches: 2,
          topInches: 2,
          bottomInches: 2,
        ),
      ),
    );
    final context = tester.element(find.byType(OcptEditorPageSetupDialog));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.editorPageSetupResetAction));
    await tester.pumpAndSettle();

    const standard = FountainPageMargins.standard();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, tr.editorPageSetupMarginLeftLabel))
          .controller
          ?.text,
      standard.leftInches.toString(),
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, tr.editorPageSetupMarginRightLabel))
          .controller
          ?.text,
      standard.rightInches.toString(),
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, tr.editorPageSetupMarginTopLabel))
          .controller
          ?.text,
      standard.topInches.toString(),
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, tr.editorPageSetupMarginBottomLabel))
          .controller
          ?.text,
      standard.bottomInches.toString(),
    );
  });

  testWidgets("Cancel pops with no value", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptEditorPageSetupDialog));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.editorPageSetupCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}
