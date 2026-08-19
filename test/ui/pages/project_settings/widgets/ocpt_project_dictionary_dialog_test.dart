// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_dictionary_dialog.dart';

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close the
/// dialog exactly as the real `GoRouter.pop` would — both push onto the very same root
/// `Navigator`. Copied from `test/ui/pages/project_settings/project_settings_page_test.dart`'s own
/// instance of the same pattern.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records the call and also pops [_navigatorKey]'s own navigator
/// when it can, so `showDialog` genuinely closes.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called at all.
  bool wasPopped = false;

  /// The value [pop] was last called with.
  Object? poppedResult;

  @override
  void pop<Y extends Object?>([Y? result]) {
    wasPopped = true;
    poppedResult = result;

    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, and
/// [_navigatorKey] so [_RecordingRouterManager.pop] can close a dialog opened through
/// `showDialog`.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: _navigatorKey,
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
    // OcptRouterManager's base class logs through appLogger(), which requires a global manager
    // instance to be set; merely accessing it creates the (otherwise unused) singleton.
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

  /// Pumps a button opening [OcptProjectDictionaryDialog.show] over [words], tapping it right
  /// away so every test starts with the dialog already on screen. [onReport] receives whatever
  /// [OcptProjectDictionaryDialog.show] resolves to, once the dialog actually closes.
  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<String> words,
    void Function(({List<String> added, List<String> removed})? report)? onReport,
  }) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final report = await OcptProjectDictionaryDialog.show(context, words: words);
              onReport?.call(report);
            },
            child: const Text("open"),
          ),
        ),
      ),
    );

    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
  }

  testWidgets("lists every word given, sorted case-insensitively", (tester) async {
    await pumpDialog(tester, words: const ["marie", "Bob", "amelie"]);

    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    expect(find.text("amelie"), findsOneWidget);
    expect(find.text("Bob"), findsOneWidget);
    expect(find.text("marie"), findsOneWidget);
    expect(find.text(tr.projectDictionaryEmptyMessage), findsNothing);
  });

  testWidgets("an empty dictionary shows its own empty-state line", (tester) async {
    await pumpDialog(tester, words: const []);

    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);
    expect(find.text(tr.projectDictionaryEmptyMessage), findsOneWidget);
  });

  testWidgets("the filter narrows the list as one types", (tester) async {
    await pumpDialog(tester, words: const ["marie", "Bob", "amelie"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.enterText(find.byType(TextField).first, "mar");
    await tester.pumpAndSettle();

    expect(find.text("marie"), findsOneWidget);
    expect(find.text("Bob"), findsNothing);
    expect(find.text("amelie"), findsNothing);
    expect(find.text(tr.projectDictionaryNoFilterMatchMessage), findsNothing);
  });

  testWidgets("a filter matching nothing shows its own distinct line", (tester) async {
    await pumpDialog(tester, words: const ["marie", "Bob"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.enterText(find.byType(TextField).first, "zzz");
    await tester.pumpAndSettle();

    expect(find.text(tr.projectDictionaryNoFilterMatchMessage), findsOneWidget);
    expect(find.text(tr.projectDictionaryEmptyMessage), findsNothing);
  });

  testWidgets("a blank add is refused silently, nothing is added", (tester) async {
    await pumpDialog(tester, words: const ["marie"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryAddAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.projectDictionaryDuplicateError), findsNothing);
    // Only the one seeded word is on screen — nothing blank got added as a row.
    expect(find.text("marie"), findsOneWidget);
  });

  testWidgets("a duplicate add is refused case-insensitively, with an error", (tester) async {
    await pumpDialog(tester, words: const ["marie"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    final addField = find.byType(TextField).last;
    await tester.enterText(addField, "MARIE");
    await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryAddAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.projectDictionaryDuplicateError), findsOneWidget);
    // Still only one "marie" row in the list: the duplicate was refused, not appended. The field
    // itself is left untouched (only a successful add clears it) — "MARIE" is still legitimately
    // showing there, in the add field's own `EditableText`, not as a second row.
    expect(find.text("marie"), findsOneWidget);

    // The error clears on the very next keystroke.
    await tester.enterText(addField, "MARIEX");
    await tester.pumpAndSettle();
    expect(find.text(tr.projectDictionaryDuplicateError), findsNothing);
  });

  testWidgets("a successful add clears the field and inserts the word in its sorted place", (
    tester,
  ) async {
    await pumpDialog(tester, words: const ["Bob", "zoe"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    final addField = find.byType(TextField).last;
    await tester.enterText(addField, "marie");
    await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryAddAction));
    await tester.pumpAndSettle();

    expect(find.text("marie"), findsOneWidget);
    expect(tester.widget<TextField>(addField).controller!.text, "");

    // Sorted case-insensitively: Bob, marie, zoe.
    final positions = ["Bob", "marie", "zoe"].map((w) => tester.getTopLeft(find.text(w)).dy);
    expect(positions.toList(), orderedEquals(List.of(positions)..sort()));
  });

  testWidgets("clicking a row's ✕ asks Remove? in place of the word", (tester) async {
    await pumpDialog(tester, words: const ["marie"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(tr.projectDictionaryRemoveTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.projectDictionaryRemoveConfirmQuestion), findsOneWidget);
    expect(find.text("marie"), findsNothing);
    expect(find.text(tr.projectDictionaryRemoveConfirmYesAction), findsOneWidget);
    expect(find.text(tr.projectDictionaryRemoveConfirmNoAction), findsOneWidget);
  });

  testWidgets("answering No leaves the word alone", (tester) async {
    await pumpDialog(tester, words: const ["marie"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(tr.projectDictionaryRemoveTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.projectDictionaryRemoveConfirmNoAction));
    await tester.pumpAndSettle();

    expect(find.text("marie"), findsOneWidget);
    expect(find.text(tr.projectDictionaryRemoveConfirmQuestion), findsNothing);
  });

  testWidgets("answering Yes drops the word from the working copy", (tester) async {
    await pumpDialog(tester, words: const ["marie", "Bob"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(tr.projectDictionaryRemoveTooltip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.projectDictionaryRemoveConfirmYesAction));
    await tester.pumpAndSettle();

    // Whichever of the two rows was first alphabetically ("Bob") is the one that was removed.
    expect(find.text("Bob"), findsNothing);
    expect(find.text("marie"), findsOneWidget);
  });

  testWidgets("only one row asks Remove? at a time", (tester) async {
    await pumpDialog(tester, words: const ["marie", "Bob"]);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(tr.projectDictionaryRemoveTooltip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tr.projectDictionaryRemoveTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.projectDictionaryRemoveConfirmQuestion), findsOneWidget);
  });

  testWidgets("Close reports the added and removed words against what was given", (tester) async {
    ({List<String> added, List<String> removed})? report;
    await pumpDialog(
      tester,
      words: const ["marie", "Bob"],
      onReport: (value) => report = value,
    );
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    // Remove "Bob".
    await tester.tap(find.byTooltip(tr.projectDictionaryRemoveTooltip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.projectDictionaryRemoveConfirmYesAction));
    await tester.pumpAndSettle();

    // Add "Zoe".
    final addField = find.byType(TextField).last;
    await tester.enterText(addField, "Zoe");
    await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryAddAction));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryCloseAction));
    await tester.pumpAndSettle();

    expect(routerManager.wasPopped, isTrue);
    expect(report, isNotNull);
    expect(report!.removed, ["Bob"]);
    expect(report!.added, ["Zoe"]);
  });

  testWidgets(
    "removing marie and adding Marie back reports both, exact-case, not a cancelled-out no-op",
    (tester) async {
      ({List<String> added, List<String> removed})? report;
      await pumpDialog(tester, words: const ["marie"], onReport: (value) => report = value);
      final context = tester.element(find.byType(OcptProjectDictionaryDialog));
      final tr = Tr.of(context);

      await tester.tap(find.byTooltip(tr.projectDictionaryRemoveTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.projectDictionaryRemoveConfirmYesAction));
      await tester.pumpAndSettle();

      final addField = find.byType(TextField).last;
      await tester.enterText(addField, "Marie");
      await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryAddAction));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryCloseAction));
      await tester.pumpAndSettle();

      expect(report, isNotNull);
      expect(report!.removed, ["marie"]);
      expect(report!.added, ["Marie"]);
    },
  );

  testWidgets("Close with nothing touched reports two empty lists", (tester) async {
    ({List<String> added, List<String> removed})? report;
    await pumpDialog(tester, words: const ["marie"], onReport: (value) => report = value);
    final context = tester.element(find.byType(OcptProjectDictionaryDialog));
    final tr = Tr.of(context);

    await tester.tap(find.widgetWithText(FilledButton, tr.projectDictionaryCloseAction));
    await tester.pumpAndSettle();

    expect(report, isNotNull);
    expect(report!.added, isEmpty);
    expect(report!.removed, isEmpty);
  });
}
